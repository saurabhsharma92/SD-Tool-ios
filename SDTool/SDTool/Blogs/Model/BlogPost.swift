//
//  BlogPost.swift
//  SDTool
//

import Foundation

// Explicitly nonisolated + Sendable so it can be used freely
// across actors without Swift 6 treating it as @MainActor
struct BlogPost: Identifiable, Sendable {
    let id:          UUID
    let title:       String
    let url:         URL
    let publishedAt: Date?
    let summary:     String?

    init(title: String, url: URL, publishedAt: Date? = nil, summary: String? = nil) {
        self.id          = UUID()
        self.title       = title
        self.url         = url
        self.publishedAt = publishedAt
        self.summary     = summary
    }

    var relativeDate: String {
        guard let date = publishedAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
