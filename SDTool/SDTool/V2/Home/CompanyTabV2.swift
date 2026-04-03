//
//  CompanyTabV2.swift
//  SDTool
//
//  Shows blog posts for a single company inside the v2 HomeV2 tab strip.
//  Also handles custom RSS feed tabs.
//

import SwiftUI
import Combine

// MARK: - Company blog tab

struct CompanyTabV2: View {
    let company: BlogCompany
    @ObservedObject private var favorites  = FavoriteStore.shared
    @StateObject    private var feedStore  = BlogFeedStore()
    @ObservedObject private var authStore  = AuthStore.shared

    var body: some View {
        NavigationStack {
            Group {
                if feedStore.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if feedStore.posts.isEmpty {
                    ContentUnavailableView(
                        "No posts",
                        systemImage: "newspaper",
                        description: Text("Could not load feed for \(company.name)")
                    )
                } else {
                    List(feedStore.posts) { post in
                        BlogRowV2(post: post, company: company)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .listStyle(.plain)
                    .refreshable { await feedStore.load(company: company) }
                }
            }
            .navigationTitle(company.name)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await feedStore.load(company: company) }
    }
}

// MARK: - Custom RSS tab

struct CustomFeedTabV2: View {
    let feed: CustomRSSFeed
    @ObservedObject private var favorites = FavoriteStore.shared
    @StateObject    private var feedStore = BlogFeedStore()

    var body: some View {
        NavigationStack {
            Group {
                if feedStore.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if feedStore.customPosts.isEmpty {
                    ContentUnavailableView(
                        "No posts",
                        systemImage: "newspaper",
                        description: Text("Could not load \(feed.displayName)")
                    )
                } else {
                    List(feedStore.customPosts) { post in
                        CustomFeedRowV2(post: post, feedName: feed.displayName)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .listStyle(.plain)
                    .refreshable { await feedStore.loadCustom(feed: feed) }
                }
            }
            .navigationTitle(feed.displayName)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await feedStore.loadCustom(feed: feed) }
    }
}

// MARK: - Blog row

struct BlogRowV2: View {
    let post:    BlogPost
    let company: BlogCompany
    @ObservedObject private var favorites  = FavoriteStore.shared
    @Environment(\.openInAppBrowser) private var openInAppBrowser

    private var isFav: Bool { favorites.isFavorite(id: post.id.uuidString) }

    var body: some View {
        HStack(spacing: 12) {
            // Company color dot
            RoundedRectangle(cornerRadius: 8)
                .fill(company.color.opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(company.emoji)
                        .font(.system(size: 16))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(post.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    if !post.relativeDate.isEmpty {
                        Text(post.relativeDate)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let summary = post.summary {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Button {
                favorites.toggle(item: FavoriteStore.blogItem(from: post, company: company))
            } label: {
                Image(systemName: isFav ? "heart.fill" : "heart")
                    .font(.system(size: 16))
                    .foregroundStyle(isFav ? .red : Color(.tertiaryLabel))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            openInAppBrowser(post.url)
        }
    }
}

// MARK: - Custom feed row

private struct CustomFeedRowV2: View {
    let post:     BlogPost
    let feedName: String
    @Environment(\.openInAppBrowser) private var openInAppBrowser

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 14))
                        .foregroundStyle(.gray)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(post.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                Text(post.relativeDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { openInAppBrowser(post.url) }
    }
}

// MARK: - Simple feed loader (wraps existing BlogFeedService)

@MainActor
final class BlogFeedStore: ObservableObject {
    @Published var posts:       [BlogPost] = []
    @Published var customPosts: [BlogPost] = []
    @Published var isLoading:   Bool       = false

    func load(company: BlogCompany) async {
        isLoading = true
        do {
            let fetched = try await BlogFeedService.shared.fetchPosts(for: company, cacheHours: 6.0)
            posts = fetched
        } catch {
            posts = []
        }
        isLoading = false
    }

    func loadCustom(feed: CustomRSSFeed) async {
        guard URL(string: feed.feedURL) != nil else { return }
        // Build a temporary BlogCompany for the custom feed to reuse BlogFeedService
        let tempCompany = BlogCompany(
            name:          feed.displayName,
            emoji:         "📡",
            category:      "Custom",
            rssURL:        feed.feedURL,
            websiteURL:    feed.feedURL,
            faviconDomain: URL(string: feed.feedURL)?.host ?? "",
            blogType:      .rss
        )
        isLoading = true
        do {
            let fetched = try await BlogFeedService.shared.fetchPosts(for: tempCompany, cacheHours: 6.0)
            customPosts = fetched
        } catch {
            customPosts = []
        }
        isLoading = false
    }
}
