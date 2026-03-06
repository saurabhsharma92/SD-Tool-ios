//
//  CompanyBlogView.swift
//  SDTool
//

import SwiftUI

struct CompanyBlogView: View {
    let company: BlogCompany

    @State private var posts:     [BlogPost] = []
    @State private var isLoading: Bool       = false
    @State private var error:     String?    = nil

    @AppStorage(AppSettings.Key.feedCacheHours) private var feedCacheHours = AppSettings.Default.feedCacheHours
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if isLoading && posts.isEmpty {
                loadingView
            } else if let error, posts.isEmpty {
                errorView(message: error)
            } else {
                postList
            }
        }
        .navigationTitle(company.name)
        .navigationBarTitleDisplayMode(.large)
        .task(id: company.id) {
            // task(id:) automatically cancels and restarts whenever
            // company.id changes — guaranteed fresh load per company
            await resetAndLoad()
        }
        .refreshable {
            await load(ignoreCache: true)
        }
    }

    // MARK: - Sub-views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading posts…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Try Again") {
                Task { await load(ignoreCache: true) }
            }
            .buttonStyle(.bordered)

            Button("Open in Browser") {
                openURL(company.websiteURL)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var postList: some View {
        List(posts) { post in
            Button {
                openURL(post.url)
            } label: {
                BlogPostRow(post: post, company: company)
            }
            .tint(.primary)
        }
        .listStyle(.insetGrouped)
        .overlay(alignment: .top) {
            if isLoading {
                ProgressView().padding(.top, 8)
            }
        }
    }

    // MARK: - Load

    /// Wipes state before loading — called when company changes
    private func resetAndLoad() async {
        posts     = []
        error     = nil
        isLoading = false
        await load()
    }

    private func load(ignoreCache: Bool = false) async {
        isLoading = true
        error     = nil

        // Show stale cache immediately while refreshing
        if let cached = await BlogFeedService.shared.cachedPosts(for: company) {
            posts = cached
        }

        if ignoreCache {
            await BlogFeedService.shared.clearCache(for: company)
        }

        do {
            posts = try await BlogFeedService.shared.fetchPosts(
                for: company,
                cacheHours: feedCacheHours
            )
            error = nil
        } catch {
            if posts.isEmpty { self.error = error.localizedDescription }
        }

        isLoading = false
    }
}
