//
//  SDValidationService.swift
//  SDTool
//
//  Validates a user's canvas graph against a problem level's solution requirements.
//  Uses a hybrid approach:
//    - Algorithmic scoring (always runs)
//    - Gemini AI feedback (auth users with quota remaining)
//    - Fallback to feedbackHint (guests or quota exhausted)
//

import Foundation
import Combine

actor SDValidationService {
    static let shared = SDValidationService()
    private init() {}

    // MARK: - Public

    func validate(
        graph: DesignGraph,
        level: SDLevel,
        isGuest: Bool,
        userId: String? = nil,
        problemId: String? = nil
    ) async -> ValidationResult {
        let score  = scoreAlgorithmically(user: graph, level: level)
        let passed = score >= 0.8

        // Compute gaps for feedback
        let reqComps  = Set(level.requiredComponents)
        let userComps = Set(graph.components)
        let reqConns  = Set(level.requiredConnections)
        let userConns = Set(graph.connections.map { $0.joined(separator: "→") })
        let missingComponents  = Array(reqComps.subtracting(userComps)).sorted()
        let missingConnections = Array(reqConns.subtracting(userConns)).sorted()
        let extraComponents    = Array(userComps.subtracting(reqComps)).sorted()

        var result: ValidationResult

        let gaps = (missing: missingComponents, missingConns: missingConnections, extra: extraComponents)

        // Guest users: skip AI entirely
        if isGuest {
            result = ValidationResult(
                passed: passed, score: score,
                aiFeedback: nil, fallbackHint: level.feedbackHint,
                isGuestFallback: true, isQuotaFallback: false,
                missingComponents: gaps.missing, missingConnections: gaps.missingConns,
                extraComponents: gaps.extra
            )
        } else {
            // Quota exhausted: skip AI
            let quotaAvailable = await MainActor.run { !AIQuotaStore.shared.isExhausted }
            if !quotaAvailable {
                result = ValidationResult(
                    passed: passed, score: score,
                    aiFeedback: nil, fallbackHint: level.feedbackHint,
                    isGuestFallback: false, isQuotaFallback: true,
                    missingComponents: gaps.missing, missingConnections: gaps.missingConns,
                    extraComponents: gaps.extra
                )
            } else {
                let aiFeedback = try? await GeminiService.shared.evaluateSystemDesign(
                    graph: graph, level: level, score: score
                )
                result = ValidationResult(
                    passed: passed, score: score,
                    aiFeedback: aiFeedback, fallbackHint: level.feedbackHint,
                    isGuestFallback: false, isQuotaFallback: false,
                    missingComponents: gaps.missing, missingConnections: gaps.missingConns,
                    extraComponents: gaps.extra
                )
            }
        }

        // Record attempt (fire-and-forget, only for authenticated users)
        if let uid = userId, let pid = problemId {
            Task {
                await SDAttemptService.shared.record(
                    userId:      uid,
                    problemId:   pid,
                    levelNumber: level.levelNumber,
                    graph:       graph,
                    result:      result
                )
            }
        }

        return result
    }

    // MARK: - Algorithmic scoring

    /// Scores a user's graph against a level's required components and connections.
    /// Uses F1 score (harmonic mean of precision + recall) so extra unnecessary
    /// components/connections reduce the score — not just missing ones.
    /// Returns a value in [0, 1] where 1.0 = exact match.
    func scoreAlgorithmically(user: DesignGraph, level: SDLevel) -> Float {
        func f1(required: Set<String>, user: Set<String>) -> Float {
            guard !required.isEmpty else { return 1.0 }
            let correct = Float(required.intersection(user).count)
            let precision: Float = user.isEmpty ? 0 : correct / Float(user.count)
            let recall:    Float = correct / Float(required.count)
            guard (precision + recall) > 0 else { return 0 }
            return 2 * precision * recall / (precision + recall)
        }

        let compScore = f1(
            required: Set(level.requiredComponents),
            user:     Set(user.components)
        )
        let connScore = f1(
            required: Set(level.requiredConnections),
            user:     Set(user.connections.map { $0.joined(separator: "→") })
        )

        return (compScore + connScore) / 2.0
    }
}
