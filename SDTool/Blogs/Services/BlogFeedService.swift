//
//  BlogFeedService.swift
//  SDTool
//

import Foundation

// MARK: - Disk structs
// Defined at file scope (not nested in actor) so Swift 6 never
// associates them with any actor's isolation domain.

private struct DiskCacheEntry: Codable, Sendable {
    var fetchedAt: Date
    var posts:     [DiskPost]
}

private struct DiskPost: Codable, Sendable {
    var title:       String
    var urlString:   String
    var publishedAt: Date?
    var summary:     String?
}

// MARK: - Free helper functions (nonisolated, no actor context)

private func encodeDiskEntry(_ entry: DiskCacheEntry) -> Data? {
    try? JSONEncoder().encode(entry)
}

private func decodeDiskEntry(_ data: Data) -> DiskCacheEntry? {
    try? JSONDecoder().decode(DiskCacheEntry.self, from: data)
}

private func makeDiskEntry(posts: [BlogPost], fetchedAt: Date) -> DiskCacheEntry {
    DiskCacheEntry(
        fetchedAt: fetchedAt,
        posts: posts.map {
            DiskPost(
                title:       $0.title,
                urlString:   $0.url.absoluteString,
                publishedAt: $0.publishedAt,
                summary:     $0.summary
            )
        }
    )
}

private func makeBlogPosts(from disk: DiskCacheEntry) -> [BlogPost] {
    disk.posts.compactMap { dp -> BlogPost? in
        guard let url = URL(string: dp.urlString) else { return nil }
        return BlogPost(
            title:       dp.title,
            url:         url,
            publishedAt: dp.publishedAt,
            summary:     dp.summary
        )
    }
}

private func checkStale(fetchedAt: Date, hours: Double) -> Bool {
    guard hours > 0 else { return true }
    return Date().timeIntervalSince(fetchedAt) > hours * 3600
}

// MARK: - Actor

actor BlogFeedService {

    static let shared = BlogFeedService()

    // Memory cache: company UUID → (fetchedAt, posts)
    private var cache: [UUID: (fetchedAt: Date, posts: [BlogPost])] = [:]
    private let keyPrefix = "rss_cache_"

    // MARK: - Public API

    func fetchPosts(for company: BlogCompany, cacheHours: Double) async throws -> [BlogPost] {
        guard let rssURL = company.rssURL else {
            throw RSSParserError.invalidURL
        }

        // Memory cache hit
        if let hit = cache[company.id], !checkStale(fetchedAt: hit.fetchedAt, hours: cacheHours) {
            return hit.posts
        }

        // Disk cache hit — load and decode outside actor via nonisolated helper
        if let posts = loadDiskCache(for: company.id, cacheHours: cacheHours) {
            cache[company.id] = (fetchedAt: Date(), posts: posts)
            return posts
        }

        // Network fetch
        let data = try await fetchData(from: rssURL)

        // Parse on detached task — RSSParser is @unchecked Sendable
        let posts: [BlogPost] = try await Task.detached(priority: .utility) {
            try RSSParser().parse(data: data)
        }.value

        guard !posts.isEmpty else { throw RSSParserError.emptyFeed }

        // Store
        let now = Date()
        cache[company.id] = (fetchedAt: now, posts: posts)
        writeDiskCache(posts: posts, fetchedAt: now, for: company.id)

        return posts
    }

    func cachedPosts(for company: BlogCompany) -> [BlogPost]? {
        if let hit = cache[company.id] { return hit.posts }
        return loadDiskCache(for: company.id, cacheHours: .infinity)
    }

    func clearCache(for company: BlogCompany) {
        cache.removeValue(forKey: company.id)
        UserDefaults.standard.removeObject(forKey: keyPrefix + company.id.uuidString)
    }

    // MARK: - Disk helpers (call free functions — no Codable inside actor)

    private func writeDiskCache(posts: [BlogPost], fetchedAt: Date, for id: UUID) {
        let entry = makeDiskEntry(posts: posts, fetchedAt: fetchedAt)
        guard let data = encodeDiskEntry(entry) else { return }
        UserDefaults.standard.set(data, forKey: keyPrefix + id.uuidString)
    }

    private func loadDiskCache(for id: UUID, cacheHours: Double) -> [BlogPost]? {
        guard
            let data  = UserDefaults.standard.data(forKey: keyPrefix + id.uuidString),
            let entry = decodeDiskEntry(data),
            !checkStale(fetchedAt: entry.fetchedAt, hours: cacheHours)
        else { return nil }
        return makeBlogPosts(from: entry)
    }

    // MARK: - Network

    private func fetchData(from url: URL) async throws -> Data {
        var req = URLRequest(url: url, timeoutInterval: 15)
        // Full browser-like Accept header — some servers (Uber, etc.) reject
        // RSS-specific Accept values and return 406
        req.setValue(
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            forHTTPHeaderField: "Accept"
        )
        req.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            + "AppleWebKit/605.1.15 (KHTML, like Gecko) "
            + "Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        req.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
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
        } catch let e as RSSParserError {
            throw e
        } catch {
            throw RSSParserError.networkError(error)
        }
    }
}
