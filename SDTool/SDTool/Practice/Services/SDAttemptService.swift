//
//  SDAttemptService.swift
//  SDTool
//
//  Writes submission attempts to Firestore `sd_attempts` collection.
//  Fire-and-forget — callers do not need to await the result.
//

import Foundation
import FirebaseFirestore

actor SDAttemptService {
    static let shared = SDAttemptService()
    private let db = Firestore.firestore()
    private let collection = "sd_attempts"

    private init() {}

    // MARK: - Fetch

    func fetchAttempts(userId: String, problemId: String, levelNumber: Int) async throws -> [SDAttempt] {
        let snapshot = try await db.collection(collection)
            .whereField("userId",      isEqualTo: userId)
            .whereField("problemId",   isEqualTo: problemId)
            .whereField("levelNumber", isEqualTo: levelNumber)
            .order(by: "attemptedAt", descending: true)
            .limit(to: 20)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            guard let data = try? JSONSerialization.data(withJSONObject: doc.data()),
                  let attempt = try? JSONDecoder().decode(SDAttempt.self, from: data)
            else { return nil }
            return attempt
        }
    }

    // MARK: - Record

    func record(
        userId: String,
        problemId: String,
        levelNumber: Int,
        graph: DesignGraph,
        result: ValidationResult
    ) async {
        let attempt = SDAttempt(
            id:          UUID().uuidString,
            userId:      userId,
            problemId:   problemId,
            levelNumber: levelNumber,
            components:  graph.components,
            connections: graph.connections.map { $0.joined(separator: "→") },
            score:       result.score,
            passed:      result.passed,
            feedback:    result.aiFeedback ?? result.fallbackHint,
            attemptedAt: Date().timeIntervalSince1970
        )

        do {
            let data = try JSONEncoder().encode(attempt)
            let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            try await db.collection(collection).document(attempt.id).setData(dict)
        } catch {
            // Non-critical — silently ignore logging failures
        }
    }
}
