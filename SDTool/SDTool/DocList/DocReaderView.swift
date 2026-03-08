//
//  DocReaderView.swift
//  SDTool
//
//  Created by Saurabh Sharma on 2/28/26.
//

import SwiftUI
import MarkdownUI
import WebKit

// MARK: - Markdown Segment

/// Splits a markdown string into alternating text / mermaid blocks.
private enum MDSegment {
    case markdown(String)
    case mermaid(String)
}

private func splitSegments(_ raw: String) -> [MDSegment] {
    var segments: [MDSegment] = []
    let pattern = #"```mermaid[ \t]*\r?\n([\s\S]*?)```"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return [.markdown(raw)]
    }

    let ns = raw as NSString
    let full = NSRange(location: 0, length: ns.length)
    var cursor = 0

    for match in regex.matches(in: raw, range: full) {
        let blockRange = match.range        // the whole ```mermaid … ``` fence
        let codeRange  = match.range(at: 1) // just the diagram source

        // text before this mermaid block
        if blockRange.location > cursor {
            let textRange = NSRange(location: cursor,
                                    length: blockRange.location - cursor)
            let text = ns.substring(with: textRange)
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append(.markdown(text))
            }
        }

        let code = ns.substring(with: codeRange)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        segments.append(.mermaid(code))
        cursor = blockRange.location + blockRange.length
    }

    // trailing text after last block
    if cursor < ns.length {
        let text = ns.substring(from: cursor)
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            segments.append(.markdown(text))
        }
    }

    return segments.isEmpty ? [.markdown(raw)] : segments
}

// MARK: - Mermaid WKWebView

/// A self-sizing WKWebView that renders a Mermaid diagram via mermaid.js (CDN).
/// Reports the rendered SVG height back to Swift so the frame fits exactly.
struct MermaidWebView: UIViewRepresentable {
    let diagram: String
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let ctrl = WKUserContentController()
        ctrl.add(context.coordinator, name: "heightBridge")

        let cfg = WKWebViewConfiguration()
        cfg.userContentController = ctrl

        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        wv.scrollView.bounces = false
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        // Escape the diagram string for safe embedding inside a JS template literal
        let safe = diagram
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`",  with: "\\`")
            .replacingOccurrences(of: "$",  with: "\\$")

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport"
                content="width=device-width, initial-scale=1, maximum-scale=1">
          <style>
            :root { color-scheme: light dark; }
            * { margin:0; padding:0; box-sizing:border-box; }
            body { background:transparent; font-family:-apple-system,sans-serif; }
            #container { width:100%; overflow-x:auto; padding:4px 0; }
            #container svg { max-width:100% !important; height:auto !important; display:block; }
          </style>
        </head>
        <body>
          <div id="container">
            <pre class="mermaid">\(safe)</pre>
          </div>

          <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
          <script>
            const dark = window.matchMedia('(prefers-color-scheme: dark)').matches;
            mermaid.initialize({
              startOnLoad: false,
              theme: dark ? 'dark' : 'default',
              securityLevel: 'loose',
              fontFamily: '-apple-system, sans-serif',
              fontSize: 13,
              flowchart: { useMaxWidth: true, htmlLabels: true },
              sequence:  { useMaxWidth: true }
            });

            mermaid.run({ nodes: document.querySelectorAll('.mermaid') })
              .then(() => {
                requestAnimationFrame(() => {
                  const h = document.getElementById('container').scrollHeight;
                  window.webkit.messageHandlers.heightBridge.postMessage(h);
                });
              })
              .catch(err => {
                document.getElementById('container').innerHTML =
                  '<pre style="color:red;font-size:12px;white-space:pre-wrap;">' +
                  err.message + '</pre>';
                requestAnimationFrame(() => {
                  const h = document.getElementById('container').scrollHeight;
                  window.webkit.messageHandlers.heightBridge.postMessage(h);
                });
              });
          </script>
        </body>
        </html>
        """
        wv.loadHTMLString(html, baseURL: nil)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let parent: MermaidWebView
        init(_ p: MermaidWebView) { parent = p }

        func userContentController(
            _ ucc: WKUserContentController,
            didReceive msg: WKScriptMessage
        ) {
            guard msg.name == "heightBridge" else { return }
            let raw: CGFloat
            if      let d = msg.body as? Double { raw = CGFloat(d) }
            else if let i = msg.body as? Int    { raw = CGFloat(i) }
            else { return }
            DispatchQueue.main.async { self.parent.height = max(raw, 60) }
        }
    }
}

// MARK: - MermaidCard

struct MermaidCard: View {
    let code: String
    @State private var webHeight: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Diagram", systemImage: "arrow.triangle.branch")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            MermaidWebView(diagram: code, height: $webHeight)
                .frame(height: webHeight)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                )
        }
        .padding(.vertical, 6)
    }
}

// MARK: - DocReaderView

struct DocReaderView: View {
    let doc: Doc
    @State private var segments:    [MDSegment]    = []
    @State private var isLoading:   Bool           = true
    @State private var rawMarkdown: String         = ""
    @State private var showChat:    Bool           = false
    @State private var showAISheet: Bool           = false
    @State private var aiMode:      ArticleAIMode  = .summarize
    @State private var hasRecordedOpen: Bool       = false

    private let progressStore = ReadingProgressStore.shared

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            if isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                        switch seg {
                        case .markdown(let text):
                            Markdown(text)
                                .markdownTheme(.gitHub)
                                .textSelection(.enabled)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)

                        case .mermaid(let code):
                            MermaidCard(code: code)
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !isLoading {
                Button { showChat = true } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(Color.indigo)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                }
                .padding(20)
            }
        }
        .navigationTitle(doc.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    aiMode     = .summarize
                    showAISheet = true
                } label: {
                    Label("Summary", systemImage: "text.quote")
                }
                .disabled(isLoading)

                Button {
                    aiMode     = .eli5
                    showAISheet = true
                } label: {
                    Label("ELI5", systemImage: "face.smiling")
                }
                .disabled(isLoading)
            }
        }
        .sheet(isPresented: $showAISheet) {
            ArticleAISheet(doc: doc, rawMarkdown: rawMarkdown, mode: $aiMode)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showChat) {
            ArticleChatView(doc: doc, rawMarkdown: rawMarkdown)
        }
        .onAppear { loadContent() }
    }

    private func loadContent() {
        let localURL = DocSyncService.shared.localURL(for: doc.filename)
        guard FileManager.default.fileExists(atPath: localURL.path) else {
            let msg = "**This article has not been downloaded yet.**\n\nGo to the Articles tab and tap the download button."
            segments  = splitSegments(msg)
            isLoading = false
            return
        }
        let raw = (try? String(contentsOf: localURL, encoding: .utf8))
            ?? "Failed to load document."
        rawMarkdown = raw
        segments    = splitSegments(raw)
        isLoading   = false

        if !hasRecordedOpen {
            hasRecordedOpen = true
            ActivityStore.shared.recordArticleRead(filename: doc.filename)
            progressStore.update(doc: doc, progress: 0.01)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DocReaderView(doc: Doc(
            filename: "chat-system-design.md",
            name:     "Chat System Design",
            category: "System Design",
            state:    .remote
        ))
    }
}
