//
//  SDProgressStore.swift
//  SDTool
//
//  Singleton store for per-user, per-problem level progress.
//  Hydrates from Firestore on demand (per problem view open).
//

import Foundation
import Combine

@MainActor
final class SDProgressStore: ObservableObject {
    static let shared = SDProgressStore()

    /// keyed by problemId
    @Published private(set) var progressMap: [String: SDProgress] = [:]

    private init() {}

    // MARK: - Queries

    func progress(for problemId: String) -> SDProgress? {
        progressMap[problemId]
    }

    func currentLevel(for problemId: String) -> Int {
        progressMap[problemId]?.currentLevel ?? 1
    }

    func isLevelUnlocked(_ level: Int, for problemId: String) -> Bool {
        if level == 1 { return true }
        return progressMap[problemId]?.isUnlocked(level: level) ?? false
    }

    func isLevelCompleted(_ level: Int, for problemId: String) -> Bool {
        progressMap[problemId]?.isCompleted(level: level) ?? false
    }

    // MARK: - Load

    func loadProgress(userId: String, problemId: String) async {
        if let p = try? await SDProgressService.shared.fetchProgress(userId: userId, problemId: problemId) {
            progressMap[problemId] = p
        }
    }

    // MARK: - Update

    func markLevelComplete(_ level: Int, for problemId: String, userId: String, feedback: String?) async {
        var p = progressMap[problemId] ?? SDProgress(
            userId:         userId,
            problemId:      problemId,
            completedLevels: [],
            currentLevel:   1,
            lastAttemptAt:  Date().timeIntervalSince1970,
            levelFeedback:  [:]
        )

        if !p.completedLevels.contains(level) {
            p.completedLevels.append(level)
        }
        p.currentLevel    = level + 1
        p.lastAttemptAt   = Date().timeIntervalSince1970
        if let fb = feedback { p.levelFeedback["\(level)"] = fb }

        progressMap[problemId] = p
        try? await SDProgressService.shared.saveProgress(p)
    }
}
