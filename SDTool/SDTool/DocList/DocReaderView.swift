//
//  DocReaderView.swift
//  SDTool
//
//  Renders articles in a WKWebView using PreTeXt-inspired CSS (articles.css).
//  .html articles: CSS + mermaid.js injected into <head> via loadHTMLString.
//  .md articles: rendered via marked.js CDN in the browser.
//  Auto-fetches the article on first open; subsequent opens load from cache instantly.
//

import SwiftUI
import WebKit

// MARK: - ArticleWebView

/// Full-page WKWebView that renders a pre-built HTML string.
struct ArticleWebView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView()
        wv.navigationDelegate = context.coordinator
        return wv
    }

    func updateUIView(_ wv: WKWebView, context: Context) {
        wv.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ wv: WKWebView,
                     decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if action.navigationType == .linkActivated,
               let url = action.request.url,
               url.scheme == "http" || url.scheme == "https" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

// MARK: - HTML builder helpers

private func bundledCSS() -> String {
    guard let url = Bundle.main.url(forResource: "articles", withExtension: "css"),
          let css = try? String(contentsOf: url, encoding: .utf8) else { return "" }
    return css
}

private let mermaidScript = """
<script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
<script>
  mermaid.initialize({
    startOnLoad: true,
    theme: window.matchMedia('(prefers-color-scheme:dark)').matches ? 'dark' : 'neutral',
    fontFamily: '-apple-system, sans-serif', fontSize: 13
  });
</script>
"""

/// Wraps a Markdown string in a full HTML document rendered by marked.js + mermaid.js.
private func buildHTMLForMarkdown(_ markdown: String) -> String {
    // Escape for JS template literal (backtick, backslash, dollar)
    let escaped = markdown
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "`", with: "\\`")
        .replacingOccurrences(of: "$", with: "\\$")
    return """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
      <style>\(bundledCSS())</style>
    </head>
    <body>
    <div id="content"></div>
    <script src="https://cdn.jsdelivr.net/npm/marked@9/marked.min.js"></script>
    \(mermaidScript)
    <script>
      const md = `\(escaped)`;
      document.getElementById('content').innerHTML = marked.parse(md);
      // Rewrite fenced mermaid code blocks for mermaid.js
      document.querySelectorAll('code.language-mermaid').forEach(function(el) {
        var pre = el.closest('pre');
        var div = document.createElement('pre');
        div.className = 'mermaid';
        div.textContent = el.textContent;
        pre.replaceWith(div);
      });
      mermaid.init(undefined, document.querySelectorAll('.mermaid'));
    </script>
    </body>
    </html>
    """
}

/// Injects CSS + mermaid.js into an existing HTML document string.
private func buildHTMLForHTMLDoc(_ content: String) -> String {
    let injection = "<style>\(bundledCSS())</style>\(mermaidScript)"
    if let r = content.range(of: "</head>", options: .caseInsensitive) {
        return content.replacingCharacters(in: r, with: "\(injection)</head>")
    }
    return "<head>\(injection)</head>" + content
}

private func buildHTML(content: String, filename: String) -> String {
    filename.hasSuffix(".html") ? buildHTMLForHTMLDoc(content) : buildHTMLForMarkdown(content)
}

// MARK: - DocReaderView

struct DocReaderView: View {
    let doc: Doc

    @Environment(\.dismiss) private var dismiss

    @State private var renderedHTML:   String? = nil
    @State private var rawContent:     String  = ""
    @State private var isLoading:      Bool    = true
    @State private var networkError:   String? = nil
    @State private var showChat:       Bool    = false
    @State private var showAISheet:    Bool    = false
    @State private var aiMode:         ArticleAIMode = .summarize
    @State private var hasRecordedOpen: Bool   = false

    private let progressStore = ReadingProgressStore.shared
    private var localURL: URL { DocSyncService.shared.localURL(for: doc.filename) }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = networkError {
                errorView(message: error)
            } else if let html = renderedHTML {
                ArticleWebView(html: html)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if !isLoading && networkError == nil {
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
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { aiMode = .summarize; showAISheet = true } label: {
                    Label("Summary", systemImage: "text.quote")
                }
                .disabled(isLoading || networkError != nil)

                Button { aiMode = .eli5; showAISheet = true } label: {
                    Label("ELI5", systemImage: "face.smiling")
                }
                .disabled(isLoading || networkError != nil)

                if let url = URL(string: GitHubConfig.Articles.fileURL(doc.filename)) {
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        Image(systemName: "safari")
                    }
                }
            }
        }
        .sheet(isPresented: $showAISheet) {
            ArticleAISheet(doc: doc, rawMarkdown: rawContent, mode: $aiMode)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showChat) {
            ArticleChatView(doc: doc, rawMarkdown: rawContent)
        }
        .onAppear { loadContent() }
    }

    // MARK: - Error view

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Couldn't load article")
                .font(.title3.bold())
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                networkError = nil
                isLoading    = true
                loadContent()
            } label: {
                Label("Try again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Load

    private func loadContent() {
        if FileManager.default.fileExists(atPath: localURL.path) {
            renderLocal()
        } else {
            Task {
                do {
                    _ = try await DocSyncService.shared.download(filename: doc.filename)
                    await MainActor.run { renderLocal() }
                } catch {
                    await MainActor.run {
                        isLoading    = false
                        networkError = error.localizedDescription
                    }
                }
            }
        }
    }

    private func renderLocal() {
        let content = (try? String(contentsOf: localURL, encoding: .utf8)) ?? ""
        rawContent   = content
        renderedHTML = buildHTML(content: content, filename: doc.filename)
        isLoading    = false
        recordOpenIfNeeded()
    }

    private func recordOpenIfNeeded() {
        guard !hasRecordedOpen else { return }
        hasRecordedOpen = true
        ActivityStore.shared.recordArticleRead(filename: doc.filename)
        progressStore.updateIfBetter(doc: doc, progress: 0.02)
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
