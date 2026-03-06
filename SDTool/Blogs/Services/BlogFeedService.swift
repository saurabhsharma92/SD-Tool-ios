//
//  BlogFeedService.swift
//  SDTool
//
//  Created by Saurabh Sharma on 3/5/26.

import Foundation

// MARK: - Cache entry

private struct CacheEntry {
    let posts:     [BlogPost]
    let fetchedAt: Date

    /// Cache is fresh for 30 minutes
    var isStale: Bool {
        Date().timeIntervalSince(fetchedAt) > 30 * 60
    }
}

// MARK: - Service

/// Fetches RSS feeds, parses them and caches results in memory.
/// All network work runs off the main thread via async/await.
actor BlogFeedService {

    static let shared = BlogFeedService()

    private var cache: [UUID: CacheEntry] = [:]
    private let parser = RSSParser()

    // MARK: - Public API

    /// Returns posts for a company.
    /// - Returns cached posts instantly if fresh; fetches otherwise.
    /// - Throws `RSSParserError` on network or parse failure.
    func fetchPosts(for company: BlogCompany) async throws -> [BlogPost] {

        // Return fresh cache immediately
        if let entry = cache[company.id], !entry.isStale {
            return entry.posts
        }

        // Fetch from network
        let data = try await fetchData(from: company.rssURL)

        // Parse on current (background) actor context
        let posts = try parser.parse(data: data)

        guard !posts.isEmpty else {
            throw RSSParserError.emptyFeed
        }

        // Store in cache
        cache[company.id] = CacheEntry(posts: posts, fetchedAt: Date())
        return posts
    }

    /// Returns cached posts without triggering a network fetch.
    /// Useful for showing stale data while a refresh is in progress.
    func cachedPosts(for company: BlogCompany) -> [BlogPost]? {
        cache[company.id]?.posts
    }

    /// Clears the entire in-memory cache.
    func clearCache() {
        cache.removeAll()
    }

    // MARK: - Private

    private func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 15)
        // Some feeds reject requests without a User-Agent
        request.setValue("SDTool/1.0 (iOS RSS Reader)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse,
               !(200..<300).contains(http.statusCode) {
                throw RSSParserError.networkError(
                    NSError(
                        domain: "HTTP",
                        code: http.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"]
                    )
                )
            }
            return data

        } catch let error as RSSParserError {
            throw error
        } catch {
            throw RSSParserError.networkError(error)
        }
    }
}
