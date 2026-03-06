//
//  CompanyBlogView.swift
//  SDTool
//
//  Created by Saurabh Sharma on 3/5/26.
//

import SwiftUI

struct CompanyBlogView: View {
    let company: BlogCompany

    @State private var posts:     [BlogPost] = []
    @State private var isLoading: Bool       = false
    @State private var error:     String?    = nil

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
        .task { await load() }
        .refreshable { await load(ignoreCache: true) }
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

            // Fallback: open website in browser
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
                BlogPostRow(post: post)
            }
            .tint(.primary)
        }
        .listStyle(.insetGrouped)
        .overlay(alignment: .top) {
            // Subtle loading indicator while refreshing in background
            if isLoading {
                ProgressView()
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Data loading

    private func load(ignoreCache: Bool = false) async {
        isLoading = true
        error     = nil

        // Show stale cache immediately while fetching
        if let cached = await BlogFeedService.shared.cachedPosts(for: company) {
            posts = cached
        }

        if ignoreCache {
            await BlogFeedService.shared.clearCache()
        }

        do {
            posts     = try await BlogFeedService.shared.fetchPosts(for: company)
            error     = nil
        } catch {
            // Keep showing stale posts if we have them
            if posts.isEmpty {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }
}
