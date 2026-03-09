//
//  AppSettings.swift
//  SDTool
//

import SwiftUI

enum AppSettings {

    enum Key {
        static let colorScheme       = "colorScheme"
        static let homeViewStyle     = "homeViewStyle"
        static let feedCacheHours    = "feedCacheHours"   // Double 0.0 – 24.0
        static let faceIDEnabled     = "faceIDEnabled"
        static let appFont           = "appFont"
        static let fontSize          = "fontSize"
        static let geminiModel       = "geminiModel"
    }

    enum Default {
        static let colorScheme:    String = "system"
        static let homeViewStyle:  String = "list"
        static let feedCacheHours: Double = 6.0           // 6 hours default
        static let faceIDEnabled:  Bool   = true
        static let appFont:        String = "system"
        static let fontSize:       Double = 1.0   // scale multiplier 0.8–1.6
        static let geminiModel:    String = "gemini-2.5-flash-lite"
    }

    static func preferredColorScheme(for value: String) -> ColorScheme? {
        switch value {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    /// Human-readable label for the cache duration slider value
    static func cacheLabel(for hours: Double) -> String {
        if hours < 0.017 { return "Always refresh" }   // < 1 min
        if hours < 1     { return "\(Int(hours * 60)) min" }
        if hours == 1    { return "1 hour" }
        if hours == 24   { return "24 hours" }
        return "\(Int(hours)) hours"
    }


    // MARK: - Font

    enum AppFont: String, CaseIterable {
        case system    = "system"
        case serif     = "serif"
        case mono      = "mono"
        case rounded   = "rounded"

        var label: String {
            switch self {
            case .system:  return "System (Default)"
            case .serif:   return "Serif"
            case .mono:    return "Monospace"
            case .rounded: return "Rounded"
            }
        }

        var font: Font {
            switch self {
            case .system:  return .body
            case .serif:   return .system(.body, design: .serif)
            case .mono:    return .system(.body, design: .monospaced)
            case .rounded: return .system(.body, design: .rounded)
            }
        }

        var design: Font.Design {
            switch self {
            case .system:  return .default
            case .serif:   return .serif
            case .mono:    return .monospaced
            case .rounded: return .rounded
            }
        }
    }

    // MARK: - Gemini Model

    enum GeminiModel: String, CaseIterable {
        // All three models are free (no billing required) on Firebase AI Logic.
        // Source: firebase.google.com/docs/ai-logic/models
        // Daily limits are per-project (shared across all users of the app).
        // gemini-2.0-* family retired June 1, 2026 — use 2.5 variants only.
        case flashLite = "gemini-2.5-flash-lite"  // Ultra fast · 20 req/day free
        case flash     = "gemini-2.5-flash"        // Fast & intelligent · ~50 req/day free
        case pro       = "gemini-2.5-pro"          // Most capable · ~25 req/day free

        var label: String {
            switch self {
            case .flashLite: return "Gemini 2.5 Flash Lite"
            case .flash:     return "Gemini 2.5 Flash"
            case .pro:       return "Gemini 2.5 Pro"
            }
        }

        var shortLabel: String {
            switch self {
            case .flashLite: return "2.5 Flash Lite"
            case .flash:     return "2.5 Flash"
            case .pro:       return "2.5 Pro"
            }
        }

        var description: String {
            switch self {
            case .flashLite: return "Ultra fast · best for quick summaries"
            case .flash:     return "Fast & smart · best for explanations"
            case .pro:       return "Most capable · best for deep analysis"
            }
        }

        /// Approximate free-tier daily request limit (per project, shared across all users)
        /// Exact limits subject to change — see ai.google.dev/gemini-api/docs/rate-limits
        var dailyLimit: Int {
            switch self {
            case .flashLite: return 20
            case .flash:     return 50
            case .pro:       return 25
            }
        }

        var requiresBilling: Bool { false }  // all free per Firebase docs March 2026

        var enablementNote: String {
            switch self {
            case .flashLite: return "Free · 20 req/day · default"
            case .flash:     return "Free · ~50 req/day"
            case .pro:       return "Free · ~25 req/day · slowest"
            }
        }

        var modelName: String { rawValue }
    }
}