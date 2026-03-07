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
    // Filenames are empty — articles are grouped by category from the GitHub index.
    // Users can drag articles into these sections to organise manually.
    static var defaults: [DocSection] {[
        DocSection(name: "Basics",        emoji: "🧱", isDefault: true),
        DocSection(name: "AI / ML",       emoji: "🤖", isDefault: true),
        DocSection(name: "System Design", emoji: "🏗", isDefault: true),
    ]}
}
