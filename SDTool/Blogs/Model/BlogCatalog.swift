//
//  BlogCatalog.swift
//  SDTool
//
//  Created by Saurabh Sharma on 3/5/26.
//

import SwiftUI

enum BlogCatalog {

    // MARK: - All companies

    static let companies: [BlogCompany] = [

        // ── 🔵 Social & Messaging ─────────────────────────────────
        BlogCompany(
            name:       "Meta Engineering",
            emoji:      "🔵",
            color:      Color(hex: "#1877F2"),
            category:   "Social & Messaging",
            rssURL:     "https://engineering.fb.com/feed/",
            websiteURL: "https://engineering.fb.com"
        ),
        BlogCompany(
            name:       "Slack Engineering",
            emoji:      "💬",
            color:      Color(hex: "#4A154B"),
            category:   "Social & Messaging",
            rssURL:     "https://slack.engineering/rss/",
            websiteURL: "https://slack.engineering"
        ),
        BlogCompany(
            name:       "Discord Blog",
            emoji:      "🎮",
            color:      Color(hex: "#5865F2"),
            category:   "Social & Messaging",
            rssURL:     "https://discord.com/blog/rss",
            websiteURL: "https://discord.com/blog"
        ),
        BlogCompany(
            name:       "LinkedIn Engineering",
            emoji:      "💼",
            color:      Color(hex: "#0A66C2"),
            category:   "Social & Messaging",
            rssURL:     "https://engineering.linkedin.com/blog.rss",
            websiteURL: "https://engineering.linkedin.com/blog"
        ),

        // ── 🟠 Infrastructure & Platforms ─────────────────────────
        BlogCompany(
            name:       "Uber Engineering",
            emoji:      "🚗",
            color:      Color(hex: "#000000"),
            category:   "Infrastructure & Platforms",
            rssURL:     "https://eng.uber.com/feed/",
            websiteURL: "https://eng.uber.com"
        ),
        BlogCompany(
            name:       "Airbnb Tech",
            emoji:      "🏠",
            color:      Color(hex: "#FF5A5F"),
            category:   "Infrastructure & Platforms",
            rssURL:     "https://medium.com/feed/airbnb-engineering",
            websiteURL: "https://medium.com/airbnb-engineering"
        ),
        BlogCompany(
            name:       "Cloudflare Blog",
            emoji:      "☁️",
            color:      Color(hex: "#F6821F"),
            category:   "Infrastructure & Platforms",
            rssURL:     "https://blog.cloudflare.com/rss/",
            websiteURL: "https://blog.cloudflare.com"
        ),
        BlogCompany(
            name:       "Lyft Engineering",
            emoji:      "🩷",
            color:      Color(hex: "#FF00BF"),
            category:   "Infrastructure & Platforms",
            rssURL:     "https://eng.lyft.com/feed",
            websiteURL: "https://eng.lyft.com"
        ),

        // ── 🟣 Streaming & Media ──────────────────────────────────
        BlogCompany(
            name:       "Netflix Tech Blog",
            emoji:      "🎬",
            color:      Color(hex: "#E50914"),
            category:   "Streaming & Media",
            rssURL:     "https://netflixtechblog.com/feed",
            websiteURL: "https://netflixtechblog.com"
        ),
        BlogCompany(
            name:       "Spotify Engineering",
            emoji:      "🎵",
            color:      Color(hex: "#1DB954"),
            category:   "Streaming & Media",
            rssURL:     "https://engineering.atspotify.com/feed/",
            websiteURL: "https://engineering.atspotify.com"
        ),

        // ── 🟢 Dev Tools & Cloud ──────────────────────────────────
        BlogCompany(
            name:       "GitHub Blog",
            emoji:      "🐙",
            color:      Color(hex: "#24292F"),
            category:   "Dev Tools & Cloud",
            rssURL:     "https://github.blog/feed/",
            websiteURL: "https://github.blog"
        ),
        BlogCompany(
            name:       "Atlassian Developer",
            emoji:      "🔷",
            color:      Color(hex: "#0052CC"),
            category:   "Dev Tools & Cloud",
            rssURL:     "https://www.atlassian.com/blog/rss",
            websiteURL: "https://www.atlassian.com/blog/developer"
        ),

        // ── 🔴 AI & Research ──────────────────────────────────────
        BlogCompany(
            name:       "Google AI Blog",
            emoji:      "🔴",
            color:      Color(hex: "#4285F4"),
            category:   "AI & Research",
            rssURL:     "https://blog.google/technology/ai/rss/",
            websiteURL: "https://ai.googleblog.com"
        ),
        BlogCompany(
            name:       "OpenAI Blog",
            emoji:      "🤖",
            color:      Color(hex: "#10A37F"),
            category:   "AI & Research",
            rssURL:     "https://openai.com/blog/rss/",
            websiteURL: "https://openai.com/blog"
        ),
        BlogCompany(
            name:       "Anthropic Blog",
            emoji:      "✳️",
            color:      Color(hex: "#CC785C"),
            category:   "AI & Research",
            rssURL:     "https://www.anthropic.com/rss.xml",
            websiteURL: "https://www.anthropic.com/blog"
        ),
    ]

    // MARK: - Grouped by category (preserves insertion order)

    static var categorized: [(category: String, companies: [BlogCompany])] {
        // Use an ordered approach to preserve the category order above
        var seen: [String: Int] = [:]
        var result: [(category: String, companies: [BlogCompany])] = []

        for company in companies {
            if let index = seen[company.category] {
                result[index].companies.append(company)
            } else {
                seen[company.category] = result.count
                result.append((category: company.category, companies: [company]))
            }
        }
        return result
    }
}

// MARK: - Color hex initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255
        )
    }
}

