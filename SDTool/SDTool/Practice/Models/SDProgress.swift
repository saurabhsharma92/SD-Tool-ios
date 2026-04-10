//
//  SDProgress.swift
//  SDTool
//
//  Tracks per-user, per-problem level completion.
//  Mirrors the Firestore `sd_progress` document schema.
//  Dates stored as Unix timestamps (TimeInterval) to avoid Firestore Timestamp conversion.
//

import Foundation

struct SDProgress: Codable {
    let userId: String
    let problemId: String
    var completedLevels: [Int]
    var currentLevel: Int
    var lastAttemptAt: TimeInterval   // seconds since epoch
    var levelFeedback: [String: String]   // "1" → "feedback text"

    func isCompleted(level: Int) -> Bool {
        completedLevels.contains(level)
    }

    func isUnlocked(level: Int) -> Bool {
        level == 1 || completedLevels.contains(level - 1)
    }
}
