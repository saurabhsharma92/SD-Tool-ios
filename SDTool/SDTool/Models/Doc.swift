//
//  Doc.swift
//  SDTool
//

import Foundation
import SwiftUI

enum DocState: String, Codable {
    case remote       // known from index, not on device
    case downloading  // fetch in progress
    case downloaded   // saved to Documents/articles/
}

struct Doc: Identifiable, Hashable, Codable {
    var id:         UUID
    var filename:   String       // "back-of-envelope-calculations.md"
    var name:       String       // "Back Of Envelope Calculations"
    var category:   String       // "Basics"
    var state:      DocState
    var remoteSHA:  String?      // GitHub SHA for change detection
    var localURL:   URL?         // set when downloaded

    // Compatibility shim used by DocReaderView and DocSectionStore
    var url: URL { localURL ?? URL(string: "about:blank")! }
    var isDownloaded: Bool { state == .downloaded }

    init(
        filename:  String,
        name:      String,
        category:  String   = "Uncategorized",
        state:     DocState = .remote,
        remoteSHA: String?  = nil,
        localURL:  URL?     = nil
    ) {
        self.id        = UUID()
        self.filename  = filename
        self.name      = name
        self.category  = category
        self.state     = state
        self.remoteSHA = remoteSHA
        self.localURL  = localURL
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Doc, rhs: Doc) -> Bool { lhs.id == rhs.id }

    // MARK: - Icon & color

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
