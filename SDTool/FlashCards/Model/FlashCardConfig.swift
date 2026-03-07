//
//  FlashCardConfig.swift
//  SDTool
//

import Foundation

enum FlashCardConfig {
    static let repoOwner = "saurabhsharma92"
    static let repoName  = "SD-Tool-ios"
    static let branch    = "main"
    static let folder    = "flashcards"

    /// GitHub API URL to list all files in the flashcards/ folder
    static var apiURL: String {
        "https://api.github.com/repos/\(repoOwner)/\(repoName)/contents/\(folder)?ref=\(branch)"
    }

    /// Raw content URL for a specific file
    static func rawURL(for filename: String) -> String {
        "https://raw.githubusercontent.com/\(repoOwner)/\(repoName)/\(branch)/\(folder)/\(filename)"
    }

    /// UserDefaults key for storing file SHAs
    static let shaStoreKey = "flashFileSHAs"
}
