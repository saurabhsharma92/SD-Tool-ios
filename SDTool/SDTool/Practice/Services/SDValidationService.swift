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
        problemId: String? = nil,
        problemTitle: String = ""
    ) async -> ValidationResult {
        let score  = scoreAlgorithmically(user: graph, level: level)
        let passed = score >= 0.8

        // Count-aware gap detection
        let reqCounts  = Dictionary(grouping: level.requiredComponents, by: { $0 }).mapValues { $0.count }
        let userCounts = Dictionary(grouping: graph.components, by: { $0 }).mapValues { $0.count }
        var missingComponents: [String] = []
        for (type, reqCount) in reqCounts.sorted(by: { $0.key < $1.key }) {
            let userCount = userCounts[type] ?? 0
            if userCount < reqCount {
                let msg = reqCount == 1 ? type : "\(type) (need \(reqCount), have \(userCount))"
                missingComponents.append(msg)
            }
        }
        let extraComponents = userCounts.keys.filter { (reqCounts[$0] ?? 0) == 0 }.sorted()

        let reqConns  = Set(level.requiredConnections)
        let userConns = Set(graph.connections.map { $0.joined(separator: "→") })
        let missingConnections = Array(reqConns.subtracting(userConns)).sorted()

        var result: ValidationResult

        let gaps = (missing: missingComponents, missingConns: missingConnections, extra: extraComponents)

        // Guest users: skip AI entirely
        if isGuest {
            result = ValidationResult(
                passed: passed, score: score,
                aiFeedback: nil, fallbackHint: level.feedbackHint,
                isGuestFallback: true, isQuotaFallback: false,
                missingComponents: gaps.missing, missingConnections: gaps.missingConns,
                extraComponents: gaps.extra, namingWarnings: [:]
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
                    extraComponents: gaps.extra, namingWarnings: [:]
                )
            } else {
                let aiFeedback = try? await GeminiService.shared.evaluateSystemDesign(
                    graph: graph, level: level, score: score
                )
                let namingWarnings: [String: String]
                if !graph.nodeLabels.isEmpty, !problemTitle.isEmpty {
                    namingWarnings = (try? await GeminiService.shared.validateNodeNames(
                        labels: Array(graph.nodeLabels.values),
                        problemTitle: problemTitle
                    )) ?? [:]
                } else {
                    namingWarnings = [:]
                }
                result = ValidationResult(
                    passed: passed, score: score,
                    aiFeedback: aiFeedback, fallbackHint: level.feedbackHint,
                    isGuestFallback: false, isQuotaFallback: false,
                    missingComponents: gaps.missing, missingConnections: gaps.missingConns,
                    extraComponents: gaps.extra, namingWarnings: namingWarnings
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
        func countF1(required: [String], user: [String]) -> Float {
            guard !required.isEmpty else { return 1.0 }
            var reqCounts:  [String: Int] = [:]
            var userCounts: [String: Int] = [:]
            required.forEach { reqCounts[$0,  default: 0] += 1 }
            user.forEach     { userCounts[$0, default: 0] += 1 }
            let tp = Float(reqCounts.keys.reduce(0) { $0 + min(reqCounts[$1]!, userCounts[$1, default: 0]) })
            let precision: Float = user.isEmpty ? 0 : tp / Float(user.count)
            let recall:    Float = tp / Float(required.count)
            guard (precision + recall) > 0 else { return 0 }
            return 2 * precision * recall / (precision + recall)
        }

        let compScore = countF1(
            required: level.requiredComponents,
            user:     user.components
        )
        let connScore = countF1(
            required: level.requiredConnections,
            user:     user.connections.map { $0.joined(separator: "→") }
        )

        return (compScore + connScore) / 2.0
    }
}
