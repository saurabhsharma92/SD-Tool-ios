//
//  ReadingProgressStore.swift
//  SDTool
//

import Foundation
import Combine

// MARK: - Model

struct ArticleProgress: Identifiable, Codable {
    let id:        UUID
    let filename:  String
    let name:      String
    var progress:  Double    // 0.0 – 1.0  (scroll %)
    var lastRead:  Date

    var isCompleted: Bool { progress >= 0.95 }

    var relativeDate: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: lastRead, relativeTo: Date())
    }
}

// MARK: - Store

class ReadingProgressStore: ObservableObject {
    static let shared = ReadingProgressStore()

    @Published private(set) var articles: [ArticleProgress] = []

    private let saveKey = "articleProgress"

    init() { load() }

    // MARK: - Public

    /// Updates progress — always writes (used for explicit updates)
    func update(doc: Doc, progress: Double) {
        _update(doc: doc, progress: progress)
    }

    /// Updates progress only if new value is higher than stored (used during scroll tracking)
    func updateIfBetter(doc: Doc, progress: Double) {
        let current = articles.first(where: { $0.filename == doc.filename })?.progress ?? 0
        guard progress > current else { return }
        _update(doc: doc, progress: progress)
    }

    private func _update(doc: Doc, progress: Double) {
        let filename = doc.filename
        ActivityStore.shared.recordArticleRead(filename: filename)
        if let i = articles.firstIndex(where: { $0.filename == filename }) {
            articles[i].progress = progress
            articles[i].lastRead = Date()
            let updated = articles.remove(at: i)
            articles.insert(updated, at: 0)
        } else {
            let entry = ArticleProgress(
                id:       UUID(),
                filename: filename,
                name:     doc.name,
                progress: progress,
                lastRead: Date()
            )
            articles.insert(entry, at: 0)
        }
        save()
    }

    /// Articles that have been started but not finished (0 < progress < 0.95)
    var inProgress: [ArticleProgress] {
        articles.filter { $0.progress > 0.0 && !$0.isCompleted }
    }

    /// Articles fully read
    var completed: [ArticleProgress] {
        articles.filter { $0.isCompleted }
    }

    /// All articles that have been opened (any progress)
    var recentlyOpened: [ArticleProgress] {
        articles.filter { $0.progress > 0 }
    }

    func clearAll() { clear() }

    func clear() {
        articles.removeAll()
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(articles) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    private func load() {
        guard
            let data  = UserDefaults.standard.data(forKey: saveKey),
            let saved = try? JSONDecoder().decode([ArticleProgress].self, from: data)
        else { return }
        articles = saved
    }
}
