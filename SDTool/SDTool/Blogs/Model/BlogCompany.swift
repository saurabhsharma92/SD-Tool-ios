//
//  BlogCompany.swift
//  SDTool
//

import SwiftUI

enum BlogType: String, Codable {
    case rss     // has RSS feed
    case website // browser-only, no RSS
}

struct BlogCompany: Identifiable, Hashable, Codable {
    var id:            UUID
    var name:          String
    var emoji:         String
    var category:      String
    var rssURL:        URL?
    var websiteURL:    URL
    var faviconDomain: String
    var blogType:      BlogType
    var isSubscribed:  Bool      // user has added this blog

    // Derived
    var browserOnly: Bool { blogType == .website }
    var color: Color {
        switch category {
        case "AI & Research":            return .purple
        case "Social & Messaging":       return .blue
        case "Streaming & Media":        return .red
        case "Infrastructure & Platforms": return .orange
        case "Dev Tools & Cloud":        return .green
        default:                         return .indigo
        }
    }

    init(
        name:          String,
        emoji:         String,
        category:      String,
        rssURL:        String?,
        websiteURL:    String,
        faviconDomain: String,
        blogType:      BlogType,
        isSubscribed:  Bool = false
    ) {
        self.id            = UUID()
        self.name          = name
        self.emoji         = emoji
        self.category      = category
        self.rssURL        = rssURL.flatMap { URL(string: $0) }
        self.websiteURL    = URL(string: websiteURL) ?? URL(string: "https://example.com")!
        self.faviconDomain = faviconDomain
        self.blogType      = blogType
        self.isSubscribed  = isSubscribed
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: BlogCompany, rhs: BlogCompany) -> Bool { lhs.id == rhs.id }
}
