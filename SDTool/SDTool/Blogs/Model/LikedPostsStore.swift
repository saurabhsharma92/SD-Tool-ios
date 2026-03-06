//
//  LikedPostsStore.swift
//  SDTool
//
//  Created by Saurabh Sharma on 3/5/26.
//

import Foundation
import Combine

// MARK: - Persistable post

/// A self-contained snapshot of a post — stored independently of the RSS cache
/// so liked posts survive cache clears and app restarts.
struct LikedPost: Identifiable, Codable, Equatable {
    let id:            UUID
    let title:         String
    let urlString:     String
    let publishedAt:   Date?
    let summary:       String?
    let companyName:   String
    let companyEmoji:  String
    let likedAt:       Date

    var url: URL? { URL(string: urlString) }

    var relativeDate: String {
        guard let date = publishedAt else { return "" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Store

class LikedPostsStore: ObservableObject {
    static let shared = LikedPostsStore()

    @Published private(set) var likedPosts: [LikedPost] = []

    private let saveKey = "likedPosts"

    init() { load() }

    // MARK: - Public API

    func isLiked(urlString: String) -> Bool {
        likedPosts.contains { $0.urlString == urlString }
    }

    func toggleLike(post: BlogPost, company: BlogCompany) {
        if isLiked(urlString: post.url.absoluteString) {
            unlike(urlString: post.url.absoluteString)
        } else {
            like(post: post, company: company)
        }
    }

    func like(post: BlogPost, company: BlogCompany) {
        guard !isLiked(urlString: post.url.absoluteString) else { return }
        let liked = LikedPost(
            id:           UUID(),
            title:        post.title,
            urlString:    post.url.absoluteString,
            publishedAt:  post.publishedAt,
            summary:      post.summary,
            companyName:  company.name,
            companyEmoji: company.emoji,
            likedAt:      Date()
        )
        likedPosts.insert(liked, at: 0)   // newest first
        save()
    }

    func unlike(urlString: String) {
        likedPosts.removeAll { $0.urlString == urlString }
        save()
    }

    func unlikeAll() {
        likedPosts.removeAll()
        save()
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(likedPosts) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let saved = try? JSONDecoder().decode([LikedPost].self, from: data)
        else { return }
        likedPosts = saved
    }
}
