//
//  ValidationResult.swift
//  SDTool
//
//  Result returned by SDValidationService after evaluating a canvas submission.
//

import Foundation

struct ValidationResult {
    let passed: Bool                    // score >= 0.8
    let score: Float                    // 0.0 – 1.0 algorithmic match
    let aiFeedback: String?             // nil when falling back to hint
    let fallbackHint: String            // level.feedbackHint from Firestore
    let isGuestFallback: Bool           // true → show "sign in" nudge
    let isQuotaFallback: Bool           // true → show "quota reached" nudge
    let missingComponents: [String]     // required components not in user's design
    let missingConnections: [String]    // required connections not in user's design ("A→B")
    let extraComponents: [String]       // components user added that aren't required
}
