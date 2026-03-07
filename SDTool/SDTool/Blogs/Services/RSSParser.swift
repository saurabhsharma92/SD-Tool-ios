//
//  RSSParser.swift
//  SDTool
//

import Foundation

// MARK: - Errors

enum RSSParserError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case parseError(String)
    case emptyFeed

    var errorDescription: String? {
        switch self {
        case .invalidURL:             return "Invalid feed URL."
        case .networkError(let e):    return "Network error: \(e.localizedDescription)"
        case .parseError(let detail): return "Could not parse feed: \(detail)"
        case .emptyFeed:              return "No posts found in this feed."
        }
    }
}

// MARK: - Parser

/// Parses RSS 2.0 and Atom feeds into [BlogPost].
/// Marked as nonisolated so it can be used safely from background actors
/// without triggering MainActor isolation warnings.
final class RSSParser: NSObject, XMLParserDelegate, @unchecked Sendable {

    // MARK: State

    private var posts:          [BlogPost] = []
    private var currentTitle:   String     = ""
    private var currentLink:    String     = ""
    private var currentDate:    String     = ""
    private var currentSummary: String     = ""
    private var currentText:    String     = ""
    private var insideItem:     Bool       = false
    private var isAtom:         Bool       = false

    // MARK: - Public entry point

    func parse(data: Data) throws -> [BlogPost] {
        // Reset state for each parse call so the instance is reusable
        posts          = []
        currentTitle   = ""
        currentLink    = ""
        currentDate    = ""
        currentSummary = ""
        currentText    = ""
        insideItem     = false
        isAtom         = false

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()

        if let error = parser.parserError {
            throw RSSParserError.parseError(error.localizedDescription)
        }
        return posts
    }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement element: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String]
    ) {
        let tag = element.lowercased()

        if tag == "feed" { isAtom = true }

        if tag == "item" || tag == "entry" {
            insideItem     = true
            currentTitle   = ""
            currentLink    = ""
            currentDate    = ""
            currentSummary = ""
            currentText    = ""
        }

        // Atom: <link href="..."> carries the URL as an attribute
        if insideItem && tag == "link" {
            if let href = attributes["href"], !href.isEmpty {
                currentLink = href
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideItem else { return }
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement element: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        let tag  = element.lowercased()
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if insideItem {
            switch tag {
            case "title":
                currentTitle = text

            case "link":
                // RSS 2.0: link text is the URL; Atom: already set via attribute
                if !isAtom && !text.isEmpty {
                    currentLink = text
                }

            case "pubdate", "dc:date", "published", "updated":
                if currentDate.isEmpty { currentDate = text }

            case "description", "summary", "content", "content:encoded":
                if currentSummary.isEmpty {
                    currentSummary = stripHTML(text)
                }

            case "item", "entry":
                if !currentTitle.isEmpty, let url = URL(string: currentLink) {
                    posts.append(BlogPost(
                        title:       cleanTitle(currentTitle),
                        url:         url,
                        publishedAt: parseDate(currentDate),
                        summary:     currentSummary.isEmpty ? nil : currentSummary
                    ))
                }
                insideItem = false

            default:
                break
            }
        }

        currentText = ""
    }

    // MARK: - Helpers

    private func stripHTML(_ html: String) -> String {
        var result = html.replacingOccurrences(
            of: "<[^>]+>", with: "", options: .regularExpression
        )
        let entities: [String: String] = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&#39;": "'", "&nbsp;": " ",
            "&#8216;": "\u{2018}", "&#8217;": "\u{2019}",
            "&#8220;": "\u{201C}", "&#8221;": "\u{201D}",
            "&#8211;": "\u{2013}", "&#8212;": "\u{2014}",
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        result = result
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if result.count > 200 {
            result = String(result.prefix(200)) + "…"
        }
        return result
    }

    private func cleanTitle(_ raw: String) -> String {
        var title = stripHTML(raw)
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        return title
    }

    private func parseDate(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd",
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}
