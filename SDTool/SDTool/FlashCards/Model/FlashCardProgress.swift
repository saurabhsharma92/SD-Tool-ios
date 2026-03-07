//
//  FlashCardProgress.swift
//  SDTool
//

import Foundation
import Combine

/// Stores which cards the user has marked as known.
/// Kept separate from FlashDeck so GitHub syncs never wipe progress.
class FlashCardProgress: ObservableObject {
    static let shared = FlashCardProgress()

    @Published private(set) var knownCardKeys: Set<String> = []

    private let saveKey = "knownCardKeys"

    init() { load() }

    // MARK: - Public

    func isKnown(_ card: FlashCard) -> Bool {
        knownCardKeys.contains(card.stableKey)
    }

    func markKnown(_ card: FlashCard) {
        knownCardKeys.insert(card.stableKey)
        save()
    }

    func markUnknown(_ card: FlashCard) {
        knownCardKeys.remove(card.stableKey)
        save()
    }

    /// Reset progress for all cards in a deck
    func reset(deck: FlashDeck) {
        let prefix = deck.filename + ":"
        knownCardKeys = knownCardKeys.filter { !$0.hasPrefix(prefix) }
        save()
    }

    /// Reset all progress across every deck
    func resetAll() {
        knownCardKeys.removeAll()
        save()
    }

    // MARK: - Persistence

    private func save() {
        UserDefaults.standard.set(Array(knownCardKeys), forKey: saveKey)
    }

    private func load() {
        if let saved = UserDefaults.standard.stringArray(forKey: saveKey) {
            knownCardKeys = Set(saved)
        }
    }
}
