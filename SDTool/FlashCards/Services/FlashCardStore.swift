//
//  FlashCardStore.swift
//  SDTool
//

import Foundation
import Combine

class FlashCardStore: ObservableObject {
    static let shared = FlashCardStore()

    @Published private(set) var decks: [FlashDeck] = []

    private let saveKey    = "flashDecks"
    private let shaKey     = FlashCardConfig.shaStoreKey

    // Stored SHAs: filename → last known GitHub SHA
    private(set) var fileSHAs: [String: String] = [:]

    init() {
        loadSHAs()
        load()
    }

    // MARK: - Public

    /// Returns a deck by filename
    func deck(for filename: String) -> FlashDeck? {
        decks.first { $0.filename == filename }
    }

    /// Update or insert a deck (called after sync or bundle load)
    func upsert(deck: FlashDeck) {
        if let i = decks.firstIndex(where: { $0.filename == deck.filename }) {
            // Preserve the existing UUID so progress keys remain stable
            var updated       = deck
            updated.id        = decks[i].id
            decks[i]          = updated
        } else {
            decks.append(deck)
        }
        // Sort: bundled first, then alphabetically
        decks.sort {
            if $0.isBundled != $1.isBundled { return $0.isBundled }
            return $0.displayName < $1.displayName
        }
        save()
    }

    /// Record the latest SHA for a file
    func updateSHA(_ sha: String, for filename: String) {
        fileSHAs[filename] = sha
        saveSHAs()
    }

    /// Returns true if the remote SHA differs from what we have stored
    func needsUpdate(filename: String, remoteSHA: String) -> Bool {
        fileSHAs[filename] != remoteSHA
    }

    // MARK: - First launch seed

    /// Seeds bundled decks on every launch for any missing deck.
    /// Safe to call repeatedly — only inserts decks not already in store.
    func seedBundledDecksIfNeeded() {
        let bundled = ["system-design.md", "ai-ml.md"]
        for filename in bundled {
            // Skip only if we already have this deck WITH cards
            if let existing = deck(for: filename), !existing.cards.isEmpty { continue }
            
            let cards = FlashCardParser.parseBundle(filename: filename)
            guard !cards.isEmpty else {
                print("[FlashCardStore] WARNING: Could not parse bundled file: \(filename)")
                continue
            }
            var newDeck = FlashDeck(
                filename:     filename,
                cards:        cards,
                lastSyncedAt: Date(timeIntervalSince1970: 0),
                isBundled:    true
            )
            upsert(deck: newDeck)
            print("[FlashCardStore] Seeded bundled deck: \(filename) with \(cards.count) cards")
        }
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(decks) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    private func load() {
        if let data   = UserDefaults.standard.data(forKey: saveKey),
           let saved  = try? JSONDecoder().decode([FlashDeck].self, from: data) {
            decks = saved
        }
        // Always ensure bundled decks exist
        seedBundledDecksIfNeeded()
    }

    private func saveSHAs() {
        UserDefaults.standard.set(fileSHAs, forKey: shaKey)
    }

    private func loadSHAs() {
        fileSHAs = UserDefaults.standard.dictionary(forKey: shaKey) as? [String: String] ?? [:]
    }
}
