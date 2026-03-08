//
//  AIError.swift
//  SDTool
//

import Foundation

enum AIError: LocalizedError {
    case noContent
    case networkUnavailable
    case rateLimited
    case emptyResponse
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .noContent:          return "Couldn't read the content."
        case .networkUnavailable: return "No internet connection. Please try again."
        case .rateLimited:        return "Too many requests. Try again in a minute."
        case .emptyResponse:      return "AI returned an empty response. Try again."
        case .unknown(let e):     return e.localizedDescription
        }
    }

    var systemImage: String {
        switch self {
        case .networkUnavailable: return "wifi.slash"
        case .rateLimited:        return "clock.badge.exclamationmark"
        default:                  return "exclamationmark.triangle"
        }
    }

    static func from(_ error: Error) -> AIError {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("offline") || msg.contains("network") || msg.contains("connection") {
            return .networkUnavailable
        }
        if msg.contains("quota") || msg.contains("rate") || msg.contains("429") {
            return .rateLimited
        }
        return .unknown(error)
    }
}
