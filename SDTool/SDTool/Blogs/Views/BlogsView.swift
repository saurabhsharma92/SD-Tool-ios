//
//  BlogsView.swift
//  SDTool
//

import SwiftUI

struct BlogsView: View {
    @StateObject private var blogStore = BlogStore.shared
    @State private var showSyncAlert  = false
    @State private var syncMessage    = ""

    var body: some View {
        NavigationStack {
            Group {
                if blogStore.companies.isEmpty && !blogStore.isSyncing {
                    emptyState
                } else {
                    blogList
                }
            }
            .navigationTitle("Blogs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if blogStore.isSyncing {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button {
                            syncBlogs()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .alert("Sync Complete", isPresented: $showSyncAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(syncMessage)
            }
            .alert("Sync Error", isPresented: .constant(blogStore.syncError != nil)) {
                Button("OK") { blogStore.syncError = nil }
            } message: {
                Text(blogStore.syncError ?? "")
            }
        }
    }

    // MARK: - Blog list

    private var blogList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {

                // ── Activity dial ──────────────────────────────────
                ActivityDialView(accentColor: .orange)
                    .padding(.top, 12)
                ActivityDialLegend(accentColor: .orange)
                    .padding(.top, 6)
                    .padding(.bottom, 4)

                // ── My Blogs ───────────────────────────────────────
                if !blogStore.subscribed.isEmpty {
                    myBlogsSectionHeader

                    ForEach(blogStore.subscribedCategories, id: \.self) { category in
                        categoryHeader(category)
                        let columns = [GridItem(.flexible(), spacing: 12),
                                       GridItem(.flexible(), spacing: 12)]
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(blogStore.subscribed(in: category)) { company in
                                NavigationLink {
                                    CompanyBlogView(company: company)
                                } label: {
                                    CompanyTileView(company: company)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    // RSS type badge
                                    Text(company.blogType == .rss ? "RSS Feed" : "Website Only")
                                    Divider()
                                    Button(role: .destructive) {
                                        blogStore.unsubscribe(company)
                                    } label: {
                                        Label("Remove Blog", systemImage: "minus.circle")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                }

                // ── Available ──────────────────────────────────────
                if !blogStore.available.isEmpty {
                    availableSectionHeader

                    ForEach(blogStore.availableCategories, id: \.self) { category in
                        categoryHeader(category)
                        ForEach(blogStore.available(in: category)) { company in
                            availableRow(company: company)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Available row

    private func availableRow(company: BlogCompany) -> some View {
        HStack(spacing: 12) {
            // Favicon
            AsyncImage(url: faviconURL(company)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFit()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                default:
                    Text(company.emoji).font(.system(size: 24))
                }
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(company.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                // Type badge
                Label(
                    company.blogType == .rss ? "RSS Feed" : "Website",
                    systemImage: company.blogType == .rss ? "dot.radiowaves.left.and.right" : "safari"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                blogStore.subscribe(company)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Section / category headers

    private func sectionHeader(_ title: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage).foregroundStyle(color)
            Text(title).font(.title3.bold())
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private func categoryHeader(_ category: String) -> some View {
        Text(category)
            .font(.subheadline.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    // MARK: - My blogs section header

    private var myBlogsSectionHeader: some View {
        Text("My Blogs")
            .font(.title3.bold())
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    // MARK: - Available section header

    private var availableSectionHeader: some View {
        Text("Available")
            .font(.title3.bold())
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "newspaper")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("No Blogs Yet")
                .font(.headline)
            Text("Tap sync to fetch the blog directory from GitHub.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Sync Now") { syncBlogs() }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sync

    private func syncBlogs() {
        let beforeCount = blogStore.companies.count
        blogStore.sync()
        // Brief delay to let sync complete for the message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard !blogStore.isSyncing else { return }
            let newCount = blogStore.companies.count - beforeCount
            syncMessage  = newCount > 0
                ? "\(newCount) new blog\(newCount > 1 ? "s" : "") added."
                : "Blog directory is up to date."
            showSyncAlert = true
        }
    }

    // MARK: - Favicon URL

    private func faviconURL(_ company: BlogCompany) -> URL? {
        URL(string: "https://www.google.com/s2/favicons?domain=\(company.faviconDomain)&sz=64")
    }
}
