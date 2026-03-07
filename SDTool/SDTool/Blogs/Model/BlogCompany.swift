//
//  BlogCompany.swift
//  SDTool
//

import SwiftUI

struct BlogCompany: Identifiable, Hashable {
    let id:            UUID
    let name:          String
    let emoji:         String
    let color:         Color
    let category:      String
    let rssURL:        URL?
    let websiteURL:    URL
    let faviconDomain: String   // always the real brand domain, never medium.com
    let browserOnly:   Bool

    init(
        name:          String,
        emoji:         String,
        color:         Color,
        category:      String,
        rssURL:        String? = nil,
        websiteURL:    String,
        faviconDomain: String? = nil,  // explicit override; falls back to websiteURL host
        browserOnly:   Bool   = false
    ) {
        self.id          = UUID()
        self.name        = name
        self.emoji       = emoji
        self.color       = color
        self.category    = category
        self.rssURL      = rssURL.flatMap { URL(string: $0) }
        self.websiteURL  = URL(string: websiteURL)!
        self.browserOnly = browserOnly
        if let explicit = faviconDomain {
            self.faviconDomain = explicit
        } else {
            self.faviconDomain = URL(string: websiteURL)?.host ?? websiteURL
        }
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: BlogCompany, rhs: BlogCompany) -> Bool { lhs.id == rhs.id }
}
