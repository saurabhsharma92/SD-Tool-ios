//
//  FlashCardParser.swift
//  SDTool
//

import Foundation

enum FlashCardParser {

    /// Parse raw text content of a .md file into [FlashCard].
    /// - Lines starting with `#` are comments — ignored
    /// - Blank lines are ignored
    /// - Valid lines must contain `=` — everything before first `=` is front, rest is back
    static func parse(content: String, filename: String) -> [FlashCard] {
        content
            .components(separatedBy: .newlines)
            .compactMap { line -> FlashCard? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                // Skip comments and blank lines
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }

                // Split on first `=` only so values can contain `=`
                guard let separatorRange = trimmed.range(of: "=") else { return nil }

                let front = String(trimmed[trimmed.startIndex..<separatorRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                let back  = String(trimmed[separatorRange.upperBound...])
                    .trimmingCharacters(in: .whitespaces)

                // Both sides must be non-empty
                guard !front.isEmpty, !back.isEmpty else { return nil }

                return FlashCard(front: front, back: back, filename: filename)
            }
    }

    /// Load and parse a bundled .md file from the app bundle.
    static func parseBundle(filename: String) -> [FlashCard] {
        let name = filename.replacingOccurrences(of: ".md", with: "")

        // 1. Try standard lookup (works when filename has no hyphens)
        if let url = Bundle.main.url(forResource: name, withExtension: "md"),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            return parse(content: content, filename: filename)
        }

        // 2. Try in "Bundled" subdirectory (matches Xcode group folder)
        if let url = Bundle.main.url(forResource: name, withExtension: "md",
                                     subdirectory: "Bundled"),
           let content = try? String(contentsOf: url, encoding: .utf8) {
            return parse(content: content, filename: filename)
        }

        // 3. Scan all .md files in bundle by exact filename (handles hyphens)
        let subdirs: [String?] = [nil, "Bundled", "FlashCards", "FlashCards/Bundled"]
        for subdir in subdirs {
            if let urls = Bundle.main.urls(forResourcesWithExtension: "md",
                                           subdirectory: subdir),
               let url = urls.first(where: { $0.lastPathComponent == filename }),
               let content = try? String(contentsOf: url, encoding: .utf8) {
                return parse(content: content, filename: filename)
            }
        }

        return []
    }
}
