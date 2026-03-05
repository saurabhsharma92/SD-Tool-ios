//
//  AppSettings.swift
//  SDTool
//
import SwiftUI

/// Centralized key constants and defaults for app preferences.
/// Views read/write preferences directly via @AppStorage(AppSettings.Key.xxx)
enum AppSettings {

    enum Key {
        static let colorScheme   = "colorScheme"    // "system" | "light" | "dark"
        static let homeViewStyle = "homeViewStyle"  // "list" | "tile"
    }

    enum Default {
        static let colorScheme:   String = "system"
        static let homeViewStyle: String = "list"
    }

    /// Converts the stored string to SwiftUI's ColorScheme type.
    static func preferredColorScheme(for value: String) -> ColorScheme? {
        switch value {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil  // nil = follow system
        }
    }
}

