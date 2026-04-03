//
//  FavoritesTabV2.swift
//  SDTool
//
//  Shows favorited articles and blog posts, grouped by type.
//

import SwiftUI

struct FavoritesTabV2: View {
    @ObservedObject private var favorites  = FavoriteStore.shared
    @Environment(\.openInAppBrowser) private var openInAppBrowser
    @State private var navPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navPath) {
            Group {
                if favorites.items.isEmpty {
                    emptyState
                } else {
                    List {
                        if !favorites.articles.isEmpty {
                            Section("Articles") {
                                ForEach(favorites.articles) { item in
                                    FavoriteArticleRow(item: item)
                                        .contentShape(Rectangle())
                                        .onTapGesture { openArticle(item) }
                                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                }
                                .onDelete { offsets in deleteArticles(at: offsets) }
                            }
                        }

                        if !favorites.blogs.isEmpty {
                            Section("Blogs") {
                                ForEach(favorites.blogs) { item in
                                    FavoriteBlogRow(item: item)
                                        .contentShape(Rectangle())
                                        .onTapGesture { openBlog(item) }
                                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                }
                                .onDelete { offsets in deleteBlogs(at: offsets) }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Doc.self) { doc in
                DocReaderView(doc: doc)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart")
                .font(.system(size: 44))
                .foregroundStyle(Color(.tertiaryLabel))
            Text("No favorites yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Tap the heart icon on any article or blog post to save it here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Navigation

    private func openArticle(_ item: FavoriteItem) {
        guard let filename = item.filename else { return }
        // Create a minimal Doc to navigate to
        let doc = Doc(
            filename: filename,
            name:     item.title,
            category: "",
            state:    .downloaded
        )
        navPath.append(doc)
    }

    private func openBlog(_ item: FavoriteItem) {
        guard let urlStr = item.blogURL, let url = URL(string: urlStr) else { return }
        openInAppBrowser(url)
    }

    // MARK: - Delete

    private func deleteArticles(at offsets: IndexSet) {
        let toDelete = offsets.map { favorites.articles[$0] }
        toDelete.forEach { favorites.remove(id: $0.id) }
    }

    private func deleteBlogs(at offsets: IndexSet) {
        let toDelete = offsets.map { favorites.blogs[$0] }
        toDelete.forEach { favorites.remove(id: $0.id) }
    }
}

// MARK: - Article row

private struct FavoriteArticleRow: View {
    let item: FavoriteItem
    @ObservedObject private var favorites = FavoriteStore.shared

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.indigo.opacity(0.1))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.indigo)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(relativeDate(item.addedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                favorites.remove(id: item.id)
            } label: {
                Image(systemName: "heart.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Blog row

private struct FavoriteBlogRow: View {
    let item: FavoriteItem
    @ObservedObject private var favorites = FavoriteStore.shared

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.teal.opacity(0.1))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.teal)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                HStack(spacing: 4) {
                    if let company = item.companyName {
                        Text(company)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Text(relativeDate(item.addedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                favorites.remove(id: item.id)
            } label: {
                Image(systemName: "heart.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Helpers

private func relativeDate(_ date: Date) -> String {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .abbreviated
    return f.localizedString(for: date, relativeTo: Date())
}
