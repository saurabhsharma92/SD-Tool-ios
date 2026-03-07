//
//  BlogSyncService.swift
//  SDTool
//

import Foundation

enum BlogSyncError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case emptyIndex

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Invalid GitHub URL."
        case .networkError(let e): return e.localizedDescription
        case .emptyIndex:          return "No blogs found in index."
        }
    }
}

actor BlogSyncService {
    static let shared = BlogSyncService()

    // MARK: - Fetch index

    func fetchIndex() async throws -> [BlogCompany] {
        guard let url = URL(string: GitHubConfig.Blogs.indexURL) else {
            throw BlogSyncError.invalidURL
        }
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue("SDTool/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            throw BlogSyncError.networkError(
                NSError(domain: "HTTP", code: http.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
            )
        }
        guard let content = String(data: data, encoding: .utf8) else {
            throw BlogSyncError.networkError(
                NSError(domain: "Decode", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Could not decode index"])
            )
        }
        let companies = parseIndex(content)
        if companies.isEmpty { throw BlogSyncError.emptyIndex }
        return companies
    }

    // MARK: - Parse
    // Format: name|rssURL|websiteURL|emoji|faviconDomain|category|type
    // rssURL = "browserOnly" for website-only companies

    private func parseIndex(_ content: String) -> [BlogCompany] {
        content
            .components(separatedBy: .newlines)
            .compactMap { line -> BlogCompany? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }

                let parts = trimmed.components(separatedBy: "|")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count >= 7 else { return nil }

                let name          = parts[0]
                let rssRaw        = parts[1]
                let websiteURL    = parts[2]
                let emoji         = parts[3]
                let faviconDomain = parts[4]
                let category      = parts[5]
                let typeRaw       = parts[6]

                let blogType: BlogType = typeRaw.lowercased() == "rss" ? .rss : .website
                let rssURL: String?    = rssRaw.lowercased() == "browseronly" ? nil : rssRaw

                guard !name.isEmpty, !websiteURL.isEmpty else { return nil }

                return BlogCompany(
                    name:          name,
                    emoji:         emoji,
                    category:      category,
                    rssURL:        rssURL,
                    websiteURL:    websiteURL,
                    faviconDomain: faviconDomain,
                    blogType:      blogType,
                    isSubscribed:  false
                )
            }
    }
}
