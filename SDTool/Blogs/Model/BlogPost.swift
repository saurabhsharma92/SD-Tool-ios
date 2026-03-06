//
//  BlogPost.swift
//  SDTool
//
//  Created by Saurabh Sharma on 3/5/26.
//

import Foundation

struct BlogPost: Identifiable {
    let id: UUID
    let title: String
    let url: URL
    let publishedAt: Date?
    let summary: String?    // plain-text snippet, HTML stripped

    init(title: String, url: URL, publishedAt: Date? = nil, summary: String? = nil) {
        self.id          = UUID()
        self.title       = title
        self.url         = url
        self.publishedAt = publishedAt
        self.summary     = summary
    }

    // MARK: - Relative date string

    var relativeDate: String {
        guard let date = publishedAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
