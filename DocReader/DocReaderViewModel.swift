//
//  DocReaderViewModel.swift
//  SDTool
//
//  Created by Saurabh Sharma on 2/28/26.
//

import Foundation
import Ink
import Gzip
import Combine

private let docsSubdirectory = "Docs"

/// Loads a doc by id from the bundle (Option B: .md.gz), decompresses, converts markdown → HTML, and wraps in the reader template.
@MainActor
final class DocReaderViewModel: ObservableObject {
    @Published var htmlContent: String?
    @Published var isLoading = true
    @Published var errorMessage: String?

    let docId: String
    let displayName: String

    init(docId: String, displayName: String) {
        self.docId = docId
        self.displayName = displayName
    }

    func load() {
        isLoading = true
        errorMessage = nil
        htmlContent = nil

        Task {
            do {
                let html = try buildHTML(docId: docId)
                await MainActor.run {
                    self.htmlContent = html
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func buildHTML(docId: String) throws -> String {
        // docId is e.g. "cache_system_design.md.gz" -> resource name "cache_system_design.md", extension "gz"
        let nameWithoutGz = docId.hasSuffix(".gz") ? String(docId.dropLast(3)) : docId
        guard let url = Bundle.main.url(forResource: nameWithoutGz, withExtension: "gz", subdirectory: docsSubdirectory)
            ?? Bundle.main.url(forResource: (nameWithoutGz as NSString).deletingPathExtension, withExtension: "gz", subdirectory: docsSubdirectory) else {
            throw NSError(domain: "DocReader", code: 1, userInfo: [NSLocalizedDescriptionKey: "Document not found: \(docId)"])
        }
        return try loadAndRender(url: url)
    }

    private func loadAndRender(url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let raw: Data
        if data.isGzipped {
            raw = try data.gunzipped()
        } else {
            raw = data
        }
        guard let markdown = String(data: raw, encoding: .utf8) else {
            throw NSError(domain: "DocReader", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid UTF-8"])
        }
        let parser = MarkdownParser()
        let bodyHTML = parser.html(from: markdown)
        return Self.wrapInTemplate(bodyHTML: bodyHTML, title: displayName)
    }

    private static func wrapInTemplate(bodyHTML: String, title: String) -> String {
        // Match web view.html: GitHub Markdown CSS, viewport, markdown-body, Mermaid for ```mermaid
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=yes">
            <title>\(title.htmlEscaped)</title>
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/github-markdown-css/5.5.1/github-markdown.min.css">
            <style>
                .markdown-body { box-sizing: border-box; min-width: 200px; max-width: 980px; margin: 0 auto; padding: 45px; font-size: 16px; }
                @media (max-width: 767px) { .markdown-body { padding: 15px; } }
                body { background-color: #f6f8fa; }
            </style>
        </head>
        <body>
        <article class="markdown-body">
        \(bodyHTML)
        </article>
        <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
        <script>
        mermaid.initialize({ startOnLoad: true, theme: 'default' });
        document.querySelectorAll('pre code.language-mermaid').forEach(function(el) {
            var pre = el.parentElement;
            var div = document.createElement('div');
            div.className = 'mermaid';
            div.textContent = el.textContent;
            pre.parentNode.replaceChild(div, pre);
        });
        </script>
        </body>
        </html>
        """
    }
}

private extension String {
    var htmlEscaped: String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    func deletingPathExtension() -> String {
        (self as NSString).deletingPathExtension
    }
}
