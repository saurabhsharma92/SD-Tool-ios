//
//  SDAttempt.swift
//  SDTool
//
//  Records a single submission attempt for a problem level.
//  Stored in Firestore `sd_attempts` collection.
//

import Foundation

struct SDAttempt: Codable {
    let id: String             // UUID string, used as Firestore document ID
    let userId: String
    let problemId: String
    let levelNumber: Int
    let components: [String]   // BlockType.rawValues present at submission
    let connections: [String]  // "A→B" format
    let score: Float
    let passed: Bool
    let feedback: String
    let attemptedAt: TimeInterval   // Unix timestamp
}
