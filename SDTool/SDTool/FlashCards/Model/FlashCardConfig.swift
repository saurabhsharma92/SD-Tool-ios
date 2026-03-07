//
//  FlashCardConfig.swift
//  SDTool
//
//  Delegates to GitHubConfig — kept for backwards compatibility.
//

import Foundation

enum FlashCardConfig {
    static var apiURL: String { GitHubConfig.FlashCards.listAPI }
    static func rawURL(for filename: String) -> String {
        GitHubConfig.FlashCards.fileURL(filename)
    }
    static let shaStoreKey = "flashFileSHAs"
}
