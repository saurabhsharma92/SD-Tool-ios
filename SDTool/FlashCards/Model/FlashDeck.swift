//
//  FlashDeck.swift
//  SDTool
//

import Foundation

struct FlashDeck: Identifiable, Codable, Equatable, Hashable {
    var id:           UUID
    var filename:     String        // "system-design.md"
    var displayName:  String        // "System Design"
    var emoji:        String        // auto-assigned based on filename
    var cards:        [FlashCard]
    var lastSyncedAt: Date?
    var remoteSHA:    String?       // last known GitHub SHA for change detection
    var isBundled:    Bool          // true = shipped with app

    init(
        filename:    String,
        cards:       [FlashCard]  = [],
        lastSyncedAt: Date?       = nil,
        remoteSHA:   String?      = nil,
        isBundled:   Bool         = false
    ) {
        self.id          = UUID()
        self.filename    = filename
        self.displayName = FlashDeck.displayName(for: filename)
        self.emoji       = FlashDeck.emoji(for: filename)
        self.cards       = cards
        self.lastSyncedAt = lastSyncedAt
        self.remoteSHA   = remoteSHA
        self.isBundled   = isBundled
    }

    // MARK: - Derived display name
    // "system-design.md" → "System Design"
    // "ai-ml.md"         → "AI / ML"
    // "databases.md"     → "Databases"
    static func displayName(for filename: String) -> String {
        let base = filename
            .replacingOccurrences(of: ".md", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")

        // Special cases
        switch base.lowercased() {
        case "ai ml", "ai-ml":  return "AI / ML"
        default:
            return base
                .split(separator: " ")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
    }

    // MARK: - Auto emoji based on filename
    static func emoji(for filename: String) -> String {
        let name = filename.lowercased()
        switch true {
        case name.contains("system"):     return "🏗"
        case name.contains("ai"):         return "🤖"
        case name.contains("ml"):         return "🧠"
        case name.contains("database"):   return "🗄️"
        case name.contains("cache"):      return "⚡️"
        case name.contains("network"):    return "🌐"
        case name.contains("security"):   return "🔒"
        case name.contains("api"):        return "🔌"
        case name.contains("cloud"):      return "☁️"
        case name.contains("distributed"): return "📡"
        default:                          return "📚"
        }
    }

    // MARK: - Stats

    var totalCards: Int { cards.count }

    func knownCount(progress: FlashCardProgress) -> Int {
        cards.filter { progress.isKnown($0) }.count
    }

    func unknownCards(progress: FlashCardProgress) -> [FlashCard] {
        cards.filter { !progress.isKnown($0) }
    }

    var lastSyncedString: String {
        guard let date = lastSyncedAt else { return "Never synced" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return "Synced \(f.localizedString(for: date, relativeTo: Date()))"
    }
}
