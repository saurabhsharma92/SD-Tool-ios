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
    case image(url: String, alt: String)
}

private func splitSegments(_ raw: String) -> [MDSegment] {
    // ── Pass 1: split on mermaid fences ─────────────────────────────
    var segments: [MDSegment] = []
    let pattern = #"```mermaid[ \t]*\r?\n([\s\S]*?)```"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return [.markdown(raw)]
    }

    let ns   = raw as NSString
    let full = NSRange(location: 0, length: ns.length)
    var cursor = 0

    for match in regex.matches(in: raw, range: full) {
        let blockRange = match.range
        let codeRange  = match.range(at: 1)

        if blockRange.location > cursor {
            let textRange = NSRange(location: cursor, length: blockRange.location - cursor)
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

    if cursor < ns.length {
        let text = ns.substring(from: cursor)
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            segments.append(.markdown(text))
        }
    }

    // ── Pass 2: extract standalone image lines ───────────────────────
    // Matches:  ![alt text](https://example.com/image.png)
    let imgRegex = try? NSRegularExpression(
        pattern: #"^!\[([^\]]*)\]\(([^)]+)\)$"#,
        options: .anchorsMatchLines
    )

    var finalSegments: [MDSegment] = []

    for seg in segments {
        guard case .markdown(let text) = seg else {
            finalSegments.append(seg)
            continue
        }

        var buffer: [String] = []

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let nsRange = NSRange(trimmed.startIndex..., in: trimmed)

            if let match = imgRegex?.firstMatch(in: trimmed, range: nsRange),
               let altRange = Range(match.range(at: 1), in: trimmed),
               let urlRange = Range(match.range(at: 2), in: trimmed) {

                // Flush buffered text first
                let buffered = buffer.joined(separator: "\n")
                if !buffered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    finalSegments.append(.markdown(buffered))
                }
                buffer.removeAll()

                finalSegments.append(.image(
                    url: String(trimmed[urlRange]),
                    alt: String(trimmed[altRange])
                ))
            } else {
                buffer.append(line)
            }
        }

        let remaining = buffer.joined(separator: "\n")
        if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            finalSegments.append(.markdown(remaining))
        }
    }

    return finalSegments.isEmpty ? [.markdown(raw)] : finalSegments
}


// MARK: - Mermaid WKWebView

/// A self-sizing WKWebView that renders a Mermaid diagram via mermaid.js (CDN).
/// Reports the rendered SVG height back to Swift so the frame fits exactly.
struct MermaidWebView: UIViewRepresentable {
    let diagram: String
    @Binding var height: CGFloat
    var onWebViewCreated: ((WKWebView) -> Void)? = nil

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
        // Report WKWebView instance back for snapshotting
        DispatchQueue.main.async { self.onWebViewCreated?(wv) }
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
    @State private var webHeight:    CGFloat    = 120
    @State private var snapshot:     UIImage?   = nil
    @State private var showFullscreen            = false
    @State private var webViewRef:   WKWebView? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Diagram", systemImage: "arrow.triangle.branch")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                Spacer()
                Button {
                    takeSnapshot()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Color.secondary.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            MermaidWebView(diagram: code, height: $webHeight, onWebViewCreated: { wv in
                webViewRef = wv
            })
            .frame(height: webHeight)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
            .onTapGesture { takeSnapshot() }
        }
        .padding(.vertical, 6)
        .fullScreenCover(isPresented: $showFullscreen) {
            ZoomableSnapshotViewer(image: snapshot, isPresented: $showFullscreen)
        }
    }

    private func takeSnapshot() {
        guard let wv = webViewRef else { return }
        let config = WKSnapshotConfiguration()
        wv.takeSnapshot(with: config) { image, _ in
            DispatchQueue.main.async {
                self.snapshot     = image
                self.showFullscreen = true
            }
        }
    }
}

// MARK: - DocReaderView

struct DocReaderView: View {
    let doc: Doc
    @State private var segments:        [MDSegment]   = []
    @State private var isLoading:       Bool          = true
    @State private var notDownloaded:   Bool          = false
    @State private var isDownloading:   Bool          = false
    @State private var downloadError:   String?       = nil
    @State private var rawMarkdown:     String        = ""
    @State private var showChat:        Bool          = false
    @State private var showAISheet:     Bool          = false
    @State private var aiMode:          ArticleAIMode = .summarize
    @State private var hasRecordedOpen: Bool          = false

    @AppStorage(AppSettings.Key.fontSize) private var fontSize = AppSettings.Default.fontSize
    @AppStorage(AppSettings.Key.appFont)  private var appFont  = AppSettings.Default.appFont

    private let progressStore = ReadingProgressStore.shared

    private var markdownTheme: MarkdownUI.Theme {
        let design = AppSettings.AppFont(rawValue: appFont)?.design ?? .default
        let basePt = 16.0 * fontSize
        return .gitHub.text {
            FontSize(basePt)
            if design == .serif {
                FontFamily(.custom("Georgia"))
            } else if design == .monospaced {
                FontFamily(.custom("Menlo"))
            }
        }
        .code {
            FontSize(basePt * 0.875)
        }
        .heading1 { configuration in
            configuration.label
                .markdownTextStyle { FontWeight(.bold); FontSize(basePt * 1.6) }
        }
        .heading2 { configuration in
            configuration.label
                .markdownTextStyle { FontWeight(.bold); FontSize(basePt * 1.4) }
        }
        .heading3 { configuration in
            configuration.label
                .markdownTextStyle { FontWeight(.semibold); FontSize(basePt * 1.2) }
        }
    }

    var body: some View {
        Group {
            if notDownloaded {
                notDownloadedView
            } else {
                GeometryReader { _ in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                    if isLoading {
                        ProgressView("Loading…")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else {
                        ForEach(Array(segments.enumerated()), id: \.offset) { index, seg in
                            Group {
                                switch seg {
                                case .markdown(let text):
                                    Markdown(text)
                                        .markdownTheme(markdownTheme)
                                        .textSelection(.enabled)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 4)
                                case .mermaid(let code):
                                    MermaidCard(code: code)
                                        .padding(.horizontal, 16)
                                case .image(let urlString, let alt):
                                    if let url = URL(string: urlString) {
                                        TappableAsyncImage(url: url, maxHeight: 260)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 6)
                                    } else {
                                        Text("[\(alt)]")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 16)
                                    }
                                }
                            }
                            // Track when each segment becomes visible
                            .onAppear {
                                guard segments.count > 0 else { return }
                                let progress = Double(index + 1) / Double(segments.count)
                                let clamped  = min(max(progress, 0.01), 1.0)
                                // Only update if meaningful forward progress
                                progressStore.updateIfBetter(doc: doc, progress: clamped)
                            }
                        }
                    }
                }
                    .padding(.vertical, 12)
                }
                } // GeometryReader
            } // else
        } // Group
        .overlay(alignment: .bottomTrailing) {
            if !isLoading && !notDownloaded {
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
                    aiMode      = .summarize
                    showAISheet = true
                } label: {
                    Label("Summary", systemImage: "text.quote")
                }
                .disabled(isLoading || notDownloaded)

                Button {
                    aiMode      = .eli5
                    showAISheet = true
                } label: {
                    Label("ELI5", systemImage: "face.smiling")
                }
                .disabled(isLoading || notDownloaded)
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

    @ViewBuilder
    private var notDownloadedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 56))
                .foregroundStyle(.indigo)
            Text("Not Downloaded")
                .font(.title2.bold())
            Text("Download this article to read it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let err = downloadError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button {
                Task { await downloadArticle() }
            } label: {
                if isDownloading {
                    ProgressView().progressViewStyle(.circular)
                        .frame(width: 100)
                } else {
                    Label("Download", systemImage: "arrow.down.circle.fill")
                        .frame(minWidth: 120)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .disabled(isDownloading)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func downloadArticle() async {
        isDownloading = true
        downloadError = nil
        do {
            _ = try await DocSyncService.shared.download(filename: doc.filename)
            notDownloaded = false
            loadContent()
        } catch {
            downloadError = error.localizedDescription
        }
        isDownloading = false
    }

    private func loadContent() {
        let localURL = DocSyncService.shared.localURL(for: doc.filename)
        guard FileManager.default.fileExists(atPath: localURL.path) else {
            notDownloaded = true
            isLoading     = false
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
            progressStore.updateIfBetter(doc: doc, progress: 0.02)
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
