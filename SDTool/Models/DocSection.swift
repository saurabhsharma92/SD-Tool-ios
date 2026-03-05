//
//  DocSection.swift
//  SDTool
//
//  Created by Saurabh Sharma on 3/4/26.
//


import Foundation

struct DocSection: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var emoji: String
    /// Ordered list of doc filenames belonging to this section
    var docFilenames: [String]

    init(id: UUID = UUID(), name: String, emoji: String, docFilenames: [String] = []) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.docFilenames = docFilenames
    }
}

// MARK: - Default sections seeded on first launch

extension DocSection {
    static let defaults: [DocSection] = [
        DocSection(
            name: "Basics",
            emoji: "🧱",
            docFilenames: [
                "back-of-envelope-calculations.md",
                "latency-numbers.md"
            ]
        ),
        DocSection(
            name: "AI / ML",
            emoji: "🤖",
            docFilenames: [
                "ai-concepts-staff-engineer-guide.md"
            ]
        ),
        DocSection(
            name: "System Design",
            emoji: "🏗",
            docFilenames: [
                "chat-system-design.md",
                "caching-system-design-reference.md",
                "drive-system-design.md"
            ]
        ),
        DocSection(
            name: "Pinned",
            emoji: "📌",
            docFilenames: []
        )
    ]
}
