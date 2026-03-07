//
//  GitHubConfig.swift
//  SDTool
//

import Foundation

enum GitHubConfig {
    static let repoOwner = "saurabhsharma92"
    static let repoName  = "SD-Tool-ios"
    static let branch    = "main"

    private static func rawURL(folder: String, file: String) -> String {
        "https://raw.githubusercontent.com/\(repoOwner)/\(repoName)/\(branch)/\(folder)/\(file)"
    }

    private static func apiURL(folder: String) -> String {
        "https://api.github.com/repos/\(repoOwner)/\(repoName)/contents/\(folder)?ref=\(branch)"
    }

    enum Articles {
        static let folder    = "articles"
        static var indexURL: String  { rawURL(folder: folder, file: "index.md") }
        static var listAPI:  String  { apiURL(folder: folder) }
        static func fileURL(_ filename: String) -> String {
            rawURL(folder: folder, file: filename)
        }
    }

    enum Blogs {
        static let folder    = "blogs"
        static var indexURL: String  { rawURL(folder: folder, file: "index.md") }
    }

    enum FlashCards {
        static let folder    = "flashcards"
        static var listAPI:  String  { apiURL(folder: folder) }
        static func fileURL(_ filename: String) -> String {
            rawURL(folder: folder, file: filename)
        }
    }
}
