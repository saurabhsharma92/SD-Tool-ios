//
//  Doc.swift
//  SDTool
//
//  Created by Saurabh Sharma on 2/28/26.
//

import Foundation

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

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Doc, rhs: Doc) -> Bool {
        lhs.id == rhs.id
    }
}
