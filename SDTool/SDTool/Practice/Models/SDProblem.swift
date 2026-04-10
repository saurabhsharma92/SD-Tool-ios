//
//  SDProblem.swift
//  SDTool
//
//  Mirrors the Firestore `sd_problems` document schema.
//  `difficulty` is intentionally not surfaced in the UI.
//

import Foundation

struct SDProblem: Identifiable, Codable, Hashable {
    let id: String           // Firestore document ID, e.g. "design-twitter"
    let title: String
    let overview: String
    let difficulty: String   // "easy" | "medium" | "hard" — used for sort order only
    let tags: [String]
    let levelCount: Int
    let levels: [SDLevel]

    var difficultyOrder: Int {
        switch difficulty {
        case "easy":  return 0
        case "hard":  return 2
        default:      return 1   // "medium" and anything unknown
        }
    }
}

struct SDLevel: Codable, Hashable {
    let levelNumber: Int
    let title: String
    let constraints: String
    let requiredComponents: [String]
    let requiredConnections: [String]   // stored as "From→To" strings in Firestore
    let feedbackHint: String
    let aiContextHint: String
}
