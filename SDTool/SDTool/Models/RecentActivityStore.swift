//
//  RecentActivityStore.swift
//  SDTool
//

import Foundation
import Combine

struct RecentDoc: Identifiable, Codable, Equatable {
    let id:        UUID
    let name:      String
    let filename:  String
    let openedAt:  Date

    var relativeDate: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: openedAt, relativeTo: Date())
    }
}

class RecentActivityStore: ObservableObject {
    static let shared = RecentActivityStore()

    @Published private(set) var recentDocs: [RecentDoc] = []

    private let saveKey  = "recentDocs"
    private let maxCount = 10

    init() { load() }

    // MARK: - Public

    func recordOpened(_ doc: Doc) {
        // Remove existing entry for same doc if present
        recentDocs.removeAll { $0.filename == doc.url.lastPathComponent }

        let recent = RecentDoc(
            id:       UUID(),
            name:     doc.name,
            filename: doc.url.lastPathComponent,
            openedAt: Date()
        )
        recentDocs.insert(recent, at: 0)

        // Keep only the last maxCount
        if recentDocs.count > maxCount {
            recentDocs = Array(recentDocs.prefix(maxCount))
        }
        save()
    }

    func clear() {
        recentDocs.removeAll()
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(recentDocs) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    private func load() {
        guard
            let data   = UserDefaults.standard.data(forKey: saveKey),
            let saved  = try? JSONDecoder().decode([RecentDoc].self, from: data)
        else { return }
        recentDocs = saved
    }
}
