//
//  Doc.swift
//  SDTool
//
//  Created by Saurabh Sharma on 2/28/26.
//

import Foundation
import SwiftUI

struct Doc: Identifiable, Hashable {
    let id: UUID
    let name: String
    let url: URL
    var isDownloaded: Bool
    var localURL: URL?

    init(name: String, url: URL, isDownloaded: Bool = false, localURL: URL? = nil) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.isDownloaded = isDownloaded
        self.localURL = localURL
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Doc, rhs: Doc) -> Bool { lhs.id == rhs.id }

    // MARK: - Category icon & color
    // Shared by DocRowView (list) and DocTileView (grid) so they always match.

    var icon: String {
        let n = name.lowercased()
        if n.contains("ai") || n.contains("machine")        { return "brain" }
        if n.contains("chat") || n.contains("message")      { return "message.fill" }
        if n.contains("cache") || n.contains("redis")       { return "bolt.fill" }
        if n.contains("drive") || n.contains("storage")     { return "externaldrive.fill" }
        if n.contains("network") || n.contains("api")       { return "network" }
        if n.contains("database") || n.contains("sql")      { return "cylinder.split.1x2.fill" }
        if n.contains("envelope") || n.contains("calculat") { return "function" }
        if n.contains("design") || n.contains("system")     { return "cpu" }
        return "doc.text.fill"
    }

    var iconColor: Color {
        let n = name.lowercased()
        if n.contains("ai") || n.contains("machine")        { return .purple }
        if n.contains("chat") || n.contains("message")      { return .green }
        if n.contains("cache") || n.contains("redis")       { return .orange }
        if n.contains("drive") || n.contains("storage")     { return .blue }
        if n.contains("envelope") || n.contains("calculat") { return .teal }
        return .indigo
    }
}


















