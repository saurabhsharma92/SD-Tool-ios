//
//  FlashCard.swift
//  SDTool
//

import Foundation

struct FlashCard: Identifiable, Codable, Equatable {
    let id:        UUID
    let front:     String       // key — shown on front of card
    let back:      String       // value — revealed on flip
    let stableKey: String       // "\(filename):\(front)" — stable across syncs

    init(front: String, back: String, filename: String) {
        self.id        = UUID()
        self.front     = front
        self.back      = back
        self.stableKey = "\(filename):\(front)"
    }
}
