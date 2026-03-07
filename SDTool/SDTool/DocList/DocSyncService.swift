//
//  DocSyncService.swift
//  SDTool
//

import Foundation

enum DocSyncError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case emptyIndex

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Invalid GitHub URL."
        case .networkError(let e): return e.localizedDescription
        case .emptyIndex:          return "No articles found in index."
        }
    }
}

actor DocSyncService {
    static let shared = DocSyncService()

    // MARK: - Fetch index

    /// Fetches articles/index.md and returns parsed (filename, name, category) tuples.
    func fetchIndex() async throws -> [(filename: String, name: String, category: String)] {
        guard let url = URL(string: GitHubConfig.Articles.indexURL) else {
            throw DocSyncError.invalidURL
        }
        let content = try await fetchText(from: url)
        let entries = parseIndex(content)
        if entries.isEmpty { throw DocSyncError.emptyIndex }
        return entries
    }

    // MARK: - Download article

    /// Downloads a single .md file and saves to Documents/articles/.
    /// Returns the local URL on success.
    func download(filename: String) async throws -> URL {
        guard let url = URL(string: GitHubConfig.Articles.fileURL(filename)) else {
            throw DocSyncError.invalidURL
        }
        let content = try await fetchText(from: url)
        let localURL = try save(content: content, filename: filename)
        return localURL
    }

    // MARK: - Parse index

    /// Parses lines like:
    ///   back-of-envelope-calculations.md=Back Of Envelope Calculations|Basics
    /// Lines starting with # or blank are ignored.
    private func parseIndex(_ content: String) -> [(filename: String, name: String, category: String)] {
        content
            .components(separatedBy: .newlines)
            .compactMap { line -> (String, String, String)? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
                guard let eqRange = trimmed.range(of: "=") else { return nil }

                let filename = String(trimmed[..<eqRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                let rest     = String(trimmed[eqRange.upperBound...])
                    .trimmingCharacters(in: .whitespaces)

                // Split rest on | to get name and optional category
                let parts    = rest.components(separatedBy: "|").map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
                let name     = parts.first ?? filename
                let category = parts.count > 1 ? parts[1] : "Uncategorized"

                guard !filename.isEmpty, !name.isEmpty else { return nil }
                return (filename, name, category)
            }
    }

    // MARK: - Save to disk

    private func save(content: String, filename: String) throws -> URL {
        let dir = articlesDirectory()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(filename)
        try content.write(to: dest, atomically: true, encoding: .utf8)
        return dest
    }

    // MARK: - Network

    private func fetchText(from url: URL) async throws -> String {
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue("SDTool/1.0", forHTTPHeaderField: "User-Agent")
        req.setValue("text/plain, */*", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                throw DocSyncError.networkError(
                    NSError(domain: "HTTP", code: http.statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
                )
            }
            guard let text = String(data: data, encoding: .utf8) else {
                throw DocSyncError.networkError(
                    NSError(domain: "Decode", code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "Could not decode response"])
                )
            }
            return text
        } catch let e as DocSyncError { throw e }
        catch { throw DocSyncError.networkError(error) }
    }

    // MARK: - Helpers

    nonisolated func articlesDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("articles")
    }

    nonisolated func localURL(for filename: String) -> URL {
        articlesDirectory().appendingPathComponent(filename)
    }

    nonisolated func fileExistsLocally(_ filename: String) -> Bool {
        FileManager.default.fileExists(atPath: localURL(for: filename).path)
    }

    nonisolated func deleteLocal(_ filename: String) throws {
        let url = localURL(for: filename)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
