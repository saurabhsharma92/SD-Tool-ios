//
//  SDProgressService.swift
//  SDTool
//
//  Reads and writes per-user level progress to Firestore `sd_progress` collection.
//  Document ID format: "{userId}_{problemId}"
//
//  SETUP REQUIRED: Add `FirebaseFirestore` to the Xcode target before building.
//

import Foundation
import FirebaseFirestore
import Combine

actor SDProgressService {
    static let shared = SDProgressService()

    private let db         = Firestore.firestore()
    private let collection = "sd_progress"

    private init() {}

    // MARK: - Helpers

    private func docId(userId: String, problemId: String) -> String {
        "\(userId)_\(problemId)"
    }

    // MARK: - Fetch

    func fetchProgress(userId: String, problemId: String) async throws -> SDProgress? {
        let doc = try await db.collection(collection)
            .document(docId(userId: userId, problemId: problemId))
            .getDocument()

        guard doc.exists, let data = doc.data() else { return nil }

        let jsonData = try JSONSerialization.data(withJSONObject: data)
        return try JSONDecoder().decode(SDProgress.self, from: jsonData)
    }

    // MARK: - Save

    func saveProgress(_ progress: SDProgress) async throws {
        let docId = docId(userId: progress.userId, problemId: progress.problemId)
        let jsonData  = try JSONEncoder().encode(progress)
        let dict      = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        try await db.collection(collection).document(docId).setData(dict)
    }
}
