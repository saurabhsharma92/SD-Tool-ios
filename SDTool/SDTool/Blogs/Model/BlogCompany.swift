//
//  BlogCompany.swift
//  SDTool
//

import SwiftUI

struct BlogCompany: Identifiable, Hashable {
    let id: UUID
    let name: String
    let emoji: String
    let color: Color
    let category: String
    let rssURL: URL?           // nil when browserOnly = true
    let websiteURL: URL
    let browserOnly: Bool      // true = no RSS, opens website directly

    init(
        name: String,
        emoji: String,
        color: Color,
        category: String,
        rssURL: String? = nil,
        websiteURL: String,
        browserOnly: Bool = false
    ) {
        self.id          = UUID()
        self.name        = name
        self.emoji       = emoji
        self.color       = color
        self.category    = category
        self.rssURL      = rssURL.flatMap { URL(string: $0) }
        self.websiteURL  = URL(string: websiteURL)!
        self.browserOnly = browserOnly
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: BlogCompany, rhs: BlogCompany) -> Bool { lhs.id == rhs.id }
}
