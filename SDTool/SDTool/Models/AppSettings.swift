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
    }

    enum Default {
        static let colorScheme:    String = "system"
        static let homeViewStyle:  String = "list"
        static let feedCacheHours: Double = 6.0           // 6 hours default
        static let faceIDEnabled:  Bool   = true
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
}
