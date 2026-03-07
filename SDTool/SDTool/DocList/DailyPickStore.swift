//
//  DailyPickStore.swift
//  SDTool
//

import Foundation
import Combine

// A specific blog post recommendation
struct DailyBlogPick: Codable {
    let companyName:  String
    let companyEmoji: String
    let postTitle:    String
    let postURLStr:   String
    let category:     String

    var postURL: URL? { URL(string: postURLStr) }
}

class DailyPickStore: ObservableObject {
    static let shared = DailyPickStore()

    @Published private(set) var articlePick: Doc?           = nil
    @Published private(set) var blogPick:    DailyBlogPick? = nil

    private let keyDate     = "dailyPickDate"
    private let keyArticle  = "dailyPickArticleFilename"
    private let keyBlogPost = "dailyPickBlogPost"

    // MARK: - Refresh article pick

    func refreshArticle(docs: [Doc]) {
        let articles = docs.filter { $0.state == .downloaded }
        guard !articles.isEmpty else { articlePick = nil; return }

        if isToday(),
           let filename = UserDefaults.standard.string(forKey: keyArticle),
           let found    = articles.first(where: { $0.filename == filename }) {
            articlePick = found
            return
        }

        let idx     = seedForToday() % articles.count
        articlePick = articles[idx]
        UserDefaults.standard.set(articles[idx].filename, forKey: keyArticle)
        saveDate()
    }

    // MARK: - Refresh blog post pick
    // Call this after blog posts are loaded for any company.
    // Pass ALL cached posts across ALL subscribed companies.

    func refreshBlogPost(allPosts: [(company: BlogCompany, posts: [BlogPost])]) {
        if isToday(),
           let data  = UserDefaults.standard.data(forKey: keyBlogPost),
           let saved = try? JSONDecoder().decode(DailyBlogPick.self, from: data) {
            blogPick = saved
            return
        }

        let flat: [(BlogCompany, BlogPost)] = allPosts.flatMap { entry in
            entry.posts.map { (entry.company, $0) }
        }
        guard !flat.isEmpty else { blogPick = nil; return }

        let idx  = (seedForToday() + 37) % flat.count
        let item = flat[idx]
        let pick = DailyBlogPick(
            companyName:  item.0.name,
            companyEmoji: item.0.emoji,
            postTitle:    item.1.title,
            postURLStr:   item.1.url.absoluteString,
            category:     item.0.category
        )
        blogPick = pick
        if let data = try? JSONEncoder().encode(pick) {
            UserDefaults.standard.set(data, forKey: keyBlogPost)
        }
        saveDate()
    }

    // MARK: - Helpers

    private func isToday() -> Bool {
        UserDefaults.standard.string(forKey: keyDate) == dayString()
    }

    private func seedForToday() -> Int {
        abs(Int(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970))
    }

    private func dayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func saveDate() {
        UserDefaults.standard.set(dayString(), forKey: keyDate)
    }
}
