//
//  CompanyBlogView.swift
//  SDTool
//

import SwiftUI

// Identifiable wrapper so .sheet(item:) always gets a fresh non-nil value
struct AISheetItem: Identifiable {
    let id   = UUID()
    let post: BlogPost
    let mode: BlogAIMode
}

struct CompanyBlogView: View {
    let company: BlogCompany

    @State private var posts:     [BlogPost] = []
    @State private var isLoading: Bool       = false
    @State private var error:     String?    = nil

    @AppStorage(AppSettings.Key.feedCacheHours) private var feedCacheHours = AppSettings.Default.feedCacheHours
    @Environment(\.openURL) private var openURL

    // AI sheet state
    @State private var aiSheet: AISheetItem? = nil

    var body: some View {
        Group {
            // browserOnly companies (Anthropic, LinkedIn etc.) — open Safari immediately
            if company.browserOnly {
                browserOnlyView
            } else if isLoading && posts.isEmpty {
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
            guard !company.browserOnly else {
                // Record activity then open browser
                ActivityStore.shared.recordBlogRead(
                    companyName: company.name,
                    postTitle:   company.name
                )
                openURL(company.websiteURL)
                return
            }
            await resetAndLoad()
        }
        .refreshable {
            guard !company.browserOnly else { return }
            await load(ignoreCache: true)
        }
    }

    // MARK: - Browser only view

    private var browserOnlyView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "safari.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
            Text("Opens in Browser")
                .font(.headline)
            Text("\(company.name) doesn't have an RSS feed. Tap below to read in Safari.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Open \(company.name)") {
                openURL(company.websiteURL)
            }
            .buttonStyle(.borderedProminent)
            Spacer()
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
            VStack(alignment: .leading, spacing: 0) {
                // Post row — tap to open in browser
                Button {
                    ActivityStore.shared.recordBlogRead(
                        companyName: company.name,
                        postTitle:   post.title
                    )
                    openURL(post.url)
                } label: {
                    BlogPostRow(post: post, company: company)
                }
                .tint(.primary)

                // AI action buttons — visible before opening browser
                HStack(spacing: 10) {
                    Button {
                        aiSheet = AISheetItem(post: post, mode: .summarize)
                    } label: {
                        Label("Summary", systemImage: "text.quote")
                            .font(.caption)
                            .foregroundStyle(.indigo)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.indigo.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        aiSheet = AISheetItem(post: post, mode: .eli5)
                    } label: {
                        Label("Explain Simply", systemImage: "face.smiling")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 8)
                .padding(.leading, 4)
            }
        }
        .listStyle(.insetGrouped)
        .overlay(alignment: .top) {
            if isLoading {
                ProgressView().padding(.top, 8)
            }
        }
        .sheet(item: $aiSheet) { item in
            BlogAISheet(post: item.post, initialMode: item.mode)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
