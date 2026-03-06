//
//  BlogCompany.swift
//  SDTool
//
//  Created by Saurabh Sharma on 3/5/26.
//

import SwiftUI

struct BlogCompany: Identifiable, Hashable {
    let id: UUID
    let name: String        // "Netflix Tech Blog"
    let emoji: String       // fallback when no SF Symbol fits
    let color: Color        // brand accent color
    let category: String    // groups companies on the home screen
    let rssURL: URL
    let websiteURL: URL

    init(
        name: String,
        emoji: String,
        color: Color,
        category: String,
        rssURL: String,
        websiteURL: String
    ) {
        self.id         = UUID()
        self.name       = name
        self.emoji      = emoji
        self.color      = color
        self.category   = category
        self.rssURL     = URL(string: rssURL)!
        self.websiteURL = URL(string: websiteURL)!
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: BlogCompany, rhs: BlogCompany) -> Bool { lhs.id == rhs.id }
}
