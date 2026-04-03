//
//  FavoriteStore.swift
//  SDTool
//
//  Persists favorited articles and blog posts for the v2 Favorites tab.
//

import Foundation
import Combine

// MARK: - Model

struct FavoriteItem: Identifiable, Codable, Equatable {
    enum ItemType: String, Codable {
        case article
        case blog
        case customFeed
    }

    var id:          String   // unique: filename for articles, blogPost.id for blogs
    var type:        ItemType
    var title:       String
    var subtitle:    String   // keywords for articles, company name for blogs
    var companyName: String?  // nil for articles
    var filename:    String?  // for articles (used to open DocReaderView)
    var blogURL:     String?  // for blogs (used to open in browser / reader)
    var addedAt:     Date
}

// MARK: - Store

final class FavoriteStore: ObservableObject {
    static let shared = FavoriteStore()

    @Published private(set) var items: [FavoriteItem] = []

    private let saveKey = "v2_favorites"
    private let ud      = UserDefaults.standard

    private init() { load() }

    // MARK: - Query

    var articles: [FavoriteItem] { items.filter { $0.type == .article } }
    var blogs:    [FavoriteItem] { items.filter { $0.type == .blog || $0.type == .customFeed } }

    func isFavorite(id: String) -> Bool {
        items.contains { $0.id == id }
    }

    // MARK: - Mutations

    func add(_ item: FavoriteItem) {
        guard !isFavorite(id: item.id) else { return }
        items.insert(item, at: 0)
        save()
    }

    func remove(id: String) {
        items.removeAll { $0.id == id }
        save()
    }

    func toggle(item: FavoriteItem) {
        if isFavorite(id: item.id) {
            remove(id: item.id)
        } else {
            add(item)
        }
    }

    // MARK: - Helpers for Article rows

    static func articleItem(from doc: Doc) -> FavoriteItem {
        FavoriteItem(
            id:          doc.filename,
            type:        .article,
            title:       doc.name,
            subtitle:    doc.filename,
            companyName: nil,
            filename:    doc.filename,
            blogURL:     nil,
            addedAt:     Date()
        )
    }

    // MARK: - Helpers for Blog rows

    static func blogItem(from post: BlogPost, company: BlogCompany) -> FavoriteItem {
        FavoriteItem(
            id:          post.id.uuidString,
            type:        .blog,
            title:       post.title,
            subtitle:    post.summary ?? post.title,
            companyName: company.name,
            filename:    nil,
            blogURL:     post.url.absoluteString,
            addedAt:     Date()
        )
    }

    // MARK: - Persistence

    private func load() {
        guard let data = ud.data(forKey: saveKey),
              let arr  = try? JSONDecoder().decode([FavoriteItem].self, from: data) else { return }
        items = arr
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            ud.set(data, forKey: saveKey)
        }
    }
}
