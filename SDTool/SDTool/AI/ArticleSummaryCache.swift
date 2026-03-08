//
//  ArticleSummaryCache.swift
//  SDTool
//

import Foundation

// In-memory cache for article context summaries.
// Avoids re-summarising the same article every time the chat sheet opens.
// Cleared when the app is terminated (intentional — keeps it simple, no stale data).

actor ArticleSummaryCache {
    static let shared = ArticleSummaryCache()
    private var cache: [String: String] = [:]  // filename → summary

    func get(_ filename: String) -> String? {
        cache[filename]
    }

    func set(_ filename: String, summary: String) {
        cache[filename] = summary
    }

    func clear() {
        cache.removeAll()
    }
}
