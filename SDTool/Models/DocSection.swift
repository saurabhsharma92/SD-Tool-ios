//
//  DocSection.swift
//  SDTool
//

import Foundation

struct DocSection: Identifiable, Codable, Equatable {
    var id:           UUID
    var name:         String
    var emoji:        String
    var docFilenames: [String]
    var isPinned:     Bool
    var isDefault:    Bool      // true = built-in, cannot be deleted

    init(
        id:           UUID     = UUID(),
        name:         String,
        emoji:        String,
        docFilenames: [String] = [],
        isPinned:     Bool     = false,
        isDefault:    Bool     = false   // user-created sections default to false
    ) {
        self.id           = id
        self.name         = name
        self.emoji        = emoji
        self.docFilenames = docFilenames
        self.isPinned     = isPinned
        self.isDefault    = isDefault
    }

    // MARK: - Built-in sections (seeded on first launch)
    static var defaults: [DocSection] {[
        DocSection(
            name:         "Basics",
            emoji:        "🧱",
            docFilenames: ["back-of-envelope-calculations.md", "latency-numbers.md"],
            isDefault:    true
        ),
        DocSection(
            name:         "AI / ML",
            emoji:        "🤖",
            docFilenames: ["ai-concepts-staff-engineer-guide.md"],
            isDefault:    true
        ),
        DocSection(
            name:         "System Design",
            emoji:        "🏗",
            docFilenames: [
                "chat-system-design.md",
                "caching-system-design-reference.md",
                "drive-system-design.md"
            ],
            isDefault:    true
        ),
    ]}
}
