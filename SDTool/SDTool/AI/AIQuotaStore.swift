//
//  AIQuotaStore.swift
//  SDTool
//
//  Tracks daily AI usage locally. Resets automatically at midnight.
//  Each call type costs 1 request against the model's daily quota.
//

import SwiftUI
import Combine

// MARK: - Call types

enum AICallType: String, CaseIterable {
    case summary = "summary"
    case explain = "explain"
    case chat    = "chat"
    case blog    = "blog"

    var label: String {
        switch self {
        case .summary: return "Summary"
        case .explain: return "Explain"
        case .chat:    return "Chat"
        case .blog:    return "Blog AI"
        }
    }

    var icon: String {
        switch self {
        case .summary: return "text.quote"
        case .explain: return "face.smiling"
        case .chat:    return "bubble.left.and.bubble.right"
        case .blog:    return "newspaper"
        }
    }
}

// MARK: - Store

final class AIQuotaStore: ObservableObject {
    static let shared = AIQuotaStore()

    // Published so all observers re-render immediately
    @Published private(set) var usedToday: Int = 0
    @Published private(set) var breakdown: [AICallType: Int] = [:]

    // Stored day key so we detect midnight rollover
    private let ud = UserDefaults.standard
    private let keyUsed      = "aiQuota_usedToday"
    private let keyDate      = "aiQuota_date"
    private let keyBreakdown = "aiQuota_breakdown"

    private init() {
        rolloverIfNeeded()
        load()
    }

    // MARK: - Public API

    /// Call this after every successful Gemini response
    func charge(_ type: AICallType) {
        rolloverIfNeeded()
        usedToday += 1
        breakdown[type, default: 0] += 1
        save()
    }

    /// Remaining requests for today given the current model's daily limit
    func remaining(for model: AppSettings.GeminiModel) -> Int {
        rolloverIfNeeded()
        return max(0, model.dailyLimit - usedToday)
    }

    /// Fraction used 0.0 – 1.0
    func fraction(for model: AppSettings.GeminiModel) -> Double {
        guard model.dailyLimit > 0 else { return 0 }
        return min(1.0, Double(usedToday) / Double(model.dailyLimit))
    }

    /// Reset (e.g. for testing)
    func reset() {
        usedToday = 0
        breakdown = [:]
        save()
    }

    // MARK: - Midnight rollover

    private func rolloverIfNeeded() {
        let today = dayKey()
        let stored = ud.string(forKey: keyDate) ?? ""
        if stored != today {
            ud.set(today, forKey: keyDate)
            ud.set(0,     forKey: keyUsed)
            ud.removeObject(forKey: keyBreakdown)
        }
    }

    private func dayKey() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone   = TimeZone(identifier: "America/Los_Angeles") // PT for Google quota reset
        return fmt.string(from: Date())
    }

    // MARK: - Persistence

    private func load() {
        usedToday = ud.integer(forKey: keyUsed)
        if let raw = ud.dictionary(forKey: keyBreakdown) as? [String: Int] {
            var parsed: [AICallType: Int] = [:]
            for (k, v) in raw {
                if let t = AICallType(rawValue: k) { parsed[t] = v }
            }
            breakdown = parsed
        }
    }

    private func save() {
        ud.set(usedToday, forKey: keyUsed)
        var raw: [String: Int] = [:]
        for (k, v) in breakdown { raw[k.rawValue] = v }
        ud.set(raw, forKey: keyBreakdown)
    }
}
