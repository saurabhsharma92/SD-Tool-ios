//
//  BlogFeedService.swift
//  SDTool
//
//  Created by Saurabh Sharma on 3/5/26.

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
/// Uses Foundation's XMLParser — no dependencies required.
final class RSSParser: NSObject, XMLParserDelegate {

    // MARK: State

    private var posts:          [BlogPost] = []
    private var currentTitle:   String     = ""
    private var currentLink:    String     = ""
    private var currentDate:    String     = ""
    private var currentSummary: String     = ""
    private var currentText:    String     = ""

    // Atom feeds use <entry>, RSS uses <item>
    private var insideItem:    Bool = false
    // Atom <link> is an attribute, not text content
    private var isAtom:        Bool = false

    // MARK: - Public entry point

    /// Parse raw XML data into posts. Call on a background thread.
    func parse(data: Data) throws -> [BlogPost] {
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

        // Detect feed format
        if tag == "feed" { isAtom = true }

        // Start of a post
        if tag == "item" || tag == "entry" {
            insideItem    = true
            currentTitle   = ""
            currentLink    = ""
            currentDate    = ""
            currentSummary = ""
            currentText    = ""
        }

        // Atom: <link href="..."> is an attribute, not text content
        if insideItem && tag == "link" {
            if let href = attributes["href"], !href.isEmpty {
                currentLink = href
            }
        }
    }

    func parser(
        _ parser: XMLParser,
        foundCharacters string: String
    ) {
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
                // RSS 2.0: link text is the URL
                // Atom: already set via attribute in didStartElement
                if !isAtom && !text.isEmpty {
                    currentLink = text
                }

            // RSS date fields
            case "pubdate", "dc:date", "published", "updated":
                if currentDate.isEmpty { currentDate = text }

            // Summary / description fields
            case "description", "summary", "content", "content:encoded":
                if currentSummary.isEmpty {
                    currentSummary = stripHTML(text)
                }

            case "item", "entry":
                // End of post — build BlogPost if we have minimum required fields
                if !currentTitle.isEmpty, let url = URL(string: currentLink) {
                    let post = BlogPost(
                        title:       cleanTitle(currentTitle),
                        url:         url,
                        publishedAt: parseDate(currentDate),
                        summary:     currentSummary.isEmpty ? nil : currentSummary
                    )
                    posts.append(post)
                }
                insideItem = false

            default:
                break
            }
        }

        currentText = ""
    }

    // MARK: - Helpers

    /// Strip HTML tags and decode common entities.
    private func stripHTML(_ html: String) -> String {
        // Remove tags
        var result = html.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        // Decode common HTML entities
        let entities: [String: String] = [
            "&amp;":  "&",
            "&lt;":   "<",
            "&gt;":   ">",
            "&quot;": "\"",
            "&#39;":  "'",
            "&nbsp;": " ",
            "&#8216;": "\u{2018}",
            "&#8217;": "\u{2019}",
            "&#8220;": "\u{201C}",
            "&#8221;": "\u{201D}",
            "&#8211;": "\u{2013}",
            "&#8212;": "\u{2014}",
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        // Collapse whitespace and trim
        result = result
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        // Truncate summary to ~200 chars
        if result.count > 200 {
            result = String(result.prefix(200)) + "…"
        }
        return result
    }

    /// Clean up title — strip HTML and normalise whitespace.
    private func cleanTitle(_ raw: String) -> String {
        var title = stripHTML(raw)
        // Remove leading/trailing quotes sometimes added by feeds
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        return title
    }

    /// Try a series of common RSS/Atom date formats.
    private func parseDate(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }

        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",     // RFC 822 (RSS)
            "EEE, dd MMM yyyy HH:mm:ss zzz",   // RFC 822 variant
            "yyyy-MM-dd'T'HH:mm:ssZ",           // ISO 8601 (Atom)
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",       // ISO 8601 with ms
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",       // ISO 8601 with offset
            "yyyy-MM-dd",                        // date only
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
}
