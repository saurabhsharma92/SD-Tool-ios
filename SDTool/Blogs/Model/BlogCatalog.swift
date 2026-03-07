//
//  BlogCatalog.swift
//  SDTool
//

import SwiftUI

struct BlogCatalog {

    static let all: [BlogCompany] = [

        // ── Social & Messaging ─────────────────────────────────────
        BlogCompany(
            name:     "Meta Engineering",
            emoji:    "👾",
            color:    .blue,
            category: "Social & Messaging",
            rssURL:   "https://engineering.fb.com/feed/",
            websiteURL: "https://engineering.fb.com"
        ),
        BlogCompany(
            name:     "Slack Engineering",
            emoji:    "💬",
            color:    .purple,
            category: "Social & Messaging",
            rssURL:   "https://slack.engineering/rss/",
            websiteURL: "https://slack.engineering"
        ),
        BlogCompany(
            name:     "Discord Blog",
            emoji:    "🎮",
            color:    .indigo,
            category: "Social & Messaging",
            rssURL:   "https://discord.com/blog/rss.xml",
            websiteURL: "https://discord.com/blog"
        ),
        BlogCompany(
            name:     "LinkedIn Engineering",
            emoji:    "💼",
            color:    .blue,
            category: "Social & Messaging",
            rssURL:   nil,
            websiteURL: "https://www.linkedin.com/blog/engineering",
            faviconDomain: "linkedin.com",
            browserOnly: true       // No accessible RSS feed — opens browser directly
        ),

        // ── Infrastructure & Platforms ─────────────────────────────
        BlogCompany(
            name:     "Uber Engineering",
            emoji:    "🚗",
            color:    .black,
            category: "Infrastructure & Platforms",
            // Medium feed returns 406; use Uber's own engineering blog RSS
            rssURL:   "https://www.uber.com/blog/engineering/rss/",
            websiteURL: "https://eng.uber.com",
            faviconDomain: "uber.com"
        ),
        BlogCompany(
            name:     "Airbnb Tech",
            emoji:    "🏠",
            color:    .pink,
            category: "Infrastructure & Platforms",
            rssURL:   "https://medium.com/feed/airbnb-engineering",
            websiteURL: "https://medium.com/airbnb-engineering",
            faviconDomain: "airbnb.com"           // feed is on Medium, logo should be Airbnb
        ),
        BlogCompany(
            name:     "Cloudflare Blog",
            emoji:    "☁️",
            color:    .orange,
            category: "Infrastructure & Platforms",
            rssURL:   "https://blog.cloudflare.com/rss/",
            websiteURL: "https://blog.cloudflare.com"
        ),
        BlogCompany(
            name:     "Lyft Engineering",
            emoji:    "🚕",
            color:    .pink,
            category: "Infrastructure & Platforms",
            rssURL:   "https://eng.lyft.com/feed",
            websiteURL: "https://eng.lyft.com",
            faviconDomain: "lyft.com"             // Medium-hosted feed, logo should be Lyft
        ),

        // ── Streaming & Media ──────────────────────────────────────
        BlogCompany(
            name:     "Netflix Tech Blog",
            emoji:    "🎬",
            color:    .red,
            category: "Streaming & Media",
            rssURL:   "https://netflixtechblog.com/feed",
            websiteURL: "https://netflixtechblog.com",
            faviconDomain: "netflix.com"          // netflixtechblog is Medium-powered
        ),
        BlogCompany(
            name:     "Spotify Engineering",
            emoji:    "🎵",
            color:    .green,
            category: "Streaming & Media",
            rssURL:   "https://engineering.atspotify.com/feed/",
            websiteURL: "https://engineering.atspotify.com"
        ),

        // ── Dev Tools & Cloud ──────────────────────────────────────
        BlogCompany(
            name:     "GitHub Blog",
            emoji:    "🐙",
            color:    .primary,
            category: "Dev Tools & Cloud",
            rssURL:   "https://github.blog/feed/",
            websiteURL: "https://github.blog"
        ),
        BlogCompany(
            name:     "Atlassian Developer",
            emoji:    "🔷",
            color:    .blue,
            category: "Dev Tools & Cloud",
            rssURL:   "https://www.atlassian.com/blog/rss",
            websiteURL: "https://www.atlassian.com/blog"
        ),

        // ── AI & Research ──────────────────────────────────────────
        BlogCompany(
            name:     "Google AI Blog",
            emoji:    "🔍",
            color:    .red,
            category: "AI & Research",
            rssURL:   "https://blog.google/technology/ai/rss/",
            websiteURL: "https://blog.google/technology/ai"
        ),
        BlogCompany(
            name:     "OpenAI",
            emoji:    "🤖",
            color:    .primary,
            category: "AI & Research",
            rssURL:   "https://openai.com/news/rss.xml",
            websiteURL: "https://openai.com"
        ),
        BlogCompany(
            name:     "Anthropic",
            emoji:    "🧠",
            color:    .orange,
            category: "AI & Research",
            rssURL:   nil,
            websiteURL: "https://anthropic.com/engineering",
            browserOnly: true
        ),
        BlogCompany(
            name:     "Hugging Face",
            emoji:    "🤗",
            color:    .yellow,
            category: "AI & Research",
            rssURL:   "https://huggingface.co/blog/feed.xml",
            websiteURL: "https://huggingface.co"
        ),
        BlogCompany(
            name:     "DeepMind",
            emoji:    "💡",
            color:    .blue,
            category: "AI & Research",
            rssURL:   "https://deepmind.google/blog/rss.xml",
            websiteURL: "https://deepmind.google"
        ),
    ]

    // MARK: - Helpers

    static var categories: [String] {
        var seen = Set<String>()
        return all.compactMap {
            seen.insert($0.category).inserted ? $0.category : nil
        }
    }

    // Alias used by BlogCategoryStore
    static var defaultCategoryOrder: [String] { categories }

    static func companies(in category: String) -> [BlogCompany] {
        all.filter { $0.category == category }
    }

    static func categorized(orderedBy order: [String]) -> [(category: String, companies: [BlogCompany])] {
        let sorted = order.isEmpty ? categories : order
        return sorted.compactMap { cat in
            let items = companies(in: cat)
            return items.isEmpty ? nil : (cat, items)
        }
    }
}
