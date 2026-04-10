//
//  SDProblemService.swift
//  SDTool
//
//  Fetches system design problems from Firestore `sd_problems` collection.
//  Falls back to a disk cache when Firestore is unavailable.
//
//  SETUP REQUIRED: Add `FirebaseFirestore` to the Xcode target before building.
//  Xcode → SDTool target → Frameworks, Libraries → + → FirebaseFirestore
//

import Foundation
import FirebaseFirestore

actor SDProblemService {
    static let shared = SDProblemService()

    private let db         = Firestore.firestore()
    private let collection = "sd_problems"

    private var cacheURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("sdProblems.json")
    }

    private init() {}

    // MARK: - Public

    /// Fetches all problems from Firestore, sorted by difficulty order.
    /// On failure, falls back to the last cached result.
    func fetchProblems() async throws -> [SDProblem] {
        do {
            let snapshot = try await db.collection(collection).getDocuments()

            let problems: [SDProblem] = try snapshot.documents.compactMap { doc in
                var data = doc.data()
                data["id"] = doc.documentID   // inject document ID (not stored in the doc body)
                let jsonData = try JSONSerialization.data(withJSONObject: data)
                return try JSONDecoder().decode(SDProblem.self, from: jsonData)
            }

            let sorted = problems.sorted { $0.difficultyOrder < $1.difficultyOrder }
            persist(sorted)
            return sorted
        } catch {
            #if DEBUG
            print("[SDProblemService] Firestore fetch failed: \(error). Falling back to cache.")
            #endif
            let cached = loadCache()
            if cached.isEmpty { throw error }
            return cached
        }
    }

    // MARK: - Cache

    private func persist(_ problems: [SDProblem]) {
        guard let data = try? JSONEncoder().encode(problems) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    private func loadCache() -> [SDProblem] {
        guard let data  = try? Data(contentsOf: cacheURL),
              let saved = try? JSONDecoder().decode([SDProblem].self, from: data) else {
            return []
        }
        return saved
    }
}
