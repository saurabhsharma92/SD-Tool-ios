//
//  BlogTextExtractor.swift
//  SDTool
//

import Foundation

actor BlogTextExtractor {
    static let shared = BlogTextExtractor()

    func extract(from url: URL) async throws -> String {
        var request = URLRequest(url: url, timeoutInterval: 15)
        // Mimic a real browser — many sites block default URLSession User-Agent
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                         forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw AIError.noContent
        }

        // Try UTF-8 first, fallback to latin1
        let html = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""

        guard !html.isEmpty else { throw AIError.noContent }
        return stripHTML(html)
    }

    // MARK: - HTML stripping

    private func stripHTML(_ html: String) -> String {
        var text = html

        // Remove <script> and <style> blocks entirely
        text = text.replacingOccurrences(
            of: #"<(script|style|nav|header|footer|aside)[^>]*>[\s\S]*?</\1>"#,
            with: " ", options: .regularExpression)

        // Remove all remaining HTML tags
        text = text.replacingOccurrences(
            of: #"<[^>]+>"#, with: " ", options: .regularExpression)

        // Decode common HTML entities
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&nbsp;", " "),
            ("&mdash;", "—"), ("&ndash;", "–"), ("&hellip;", "…")
        ]
        for (entity, char) in entities {
            text = text.replacingOccurrences(of: entity, with: char)
        }

        // Collapse whitespace
        text = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        // Trim to a reasonable length for Gemini context
        return String(text.prefix(12_000))
    }
}
