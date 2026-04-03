//
//  CompanyGroupTabV2.swift
//  SDTool
//
//  Shows aggregated blog posts from all companies in a CompanyGroup.
//

import SwiftUI
import Combine

struct CompanyGroupTabV2: View {
    let group: CompanyGroup

    @ObservedObject private var blogStore  = BlogStore.shared
    @ObservedObject private var favorites  = FavoriteStore.shared
    @StateObject    private var loader     = GroupFeedLoader()

    private var companies: [BlogCompany] {
        blogStore.companies.filter { group.companyNames.contains($0.name) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if loader.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if loader.posts.isEmpty {
                    ContentUnavailableView(
                        "No posts",
                        systemImage: "newspaper",
                        description: Text("Could not load feeds for this group")
                    )
                } else {
                    List(loader.posts, id: \.id) { item in
                        BlogRowV2(post: item.post, company: item.company)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .listStyle(.plain)
                    .refreshable { await loader.load(companies: companies) }
                }
            }
            .navigationTitle(group.name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await loader.load(companies: companies) }
        .onChange(of: group.companyNames) { _, _ in
            Task { await loader.load(companies: companies) }
        }
    }
}

// MARK: - Tagged post (post + its source company)

struct TaggedPost: Identifiable {
    let id:      UUID = UUID()
    let post:    BlogPost
    let company: BlogCompany
}

// MARK: - Loader

@MainActor
final class GroupFeedLoader: ObservableObject {
    @Published var posts:     [TaggedPost] = []
    @Published var isLoading: Bool         = false

    func load(companies: [BlogCompany]) async {
        isLoading = true
        var result: [TaggedPost] = []
        await withTaskGroup(of: [TaggedPost].self) { group in
            for company in companies {
                group.addTask {
                    let fetched = try? await BlogFeedService.shared.fetchPosts(for: company, cacheHours: 6.0)
                    return (fetched ?? []).map { TaggedPost(post: $0, company: company) }
                }
            }
            for await items in group {
                result.append(contentsOf: items)
            }
        }
        // Sort by date descending
        posts     = result.sorted {
            ($0.post.publishedAt ?? .distantPast) > ($1.post.publishedAt ?? .distantPast)
        }
        isLoading = false
    }
}
