//
//  ArticlesTabV2.swift
//  SDTool
//
//  Articles tab inside the v2 HomeV2 tab strip.
//  Clean list — no section headers, just rows with heart button.
//

import SwiftUI
import Combine

struct ArticlesTabV2: View {
    @StateObject private var docStore     = DocStore()
    @StateObject private var sectionStore = DocSectionStore()
    @ObservedObject private var favorites = FavoriteStore.shared

    @State private var navPath        = NavigationPath()
    @State private var showSyncAlert  = false
    @State private var searchText     = ""
    @State private var showContribute = false
    @State private var selectedDoc:    Doc? = nil

    private var filteredDocs: [Doc] {
        let all = docStore.docs
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(searchText) ||
                            $0.category.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack(path: $navPath) {
            Group {
                if docStore.docs.isEmpty && !docStore.isSyncing {
                    ContentUnavailableView(
                        "No articles",
                        systemImage: "doc.text",
                        description: Text("Pull to refresh or tap ↓ to sync")
                    )
                } else {
                    VStack(spacing: 0) {
                        // Compact search bar
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            TextField("Search articles", text: $searchText)
                                .font(.system(size: 14))
                            if !searchText.isEmpty {
                                Button { searchText = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 6)

                        List {
                            ForEach(filteredDocs) { doc in
                                ArticleRowV2(doc: doc)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        ActivityStore.shared.recordArticleRead(filename: doc.filename)
                                        selectedDoc = doc
                                    }
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .listRowSeparator(.visible)
                            }
                        }
                        .listStyle(.plain)
                        .refreshable { docStore.sync() }
                    }
                }
            }
            .navigationTitle("Articles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showContribute = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 13))
                            Text("Contribute")
                                .font(.system(size: 13))
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if docStore.isSyncing {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button { docStore.sync() } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(isPresented: $showContribute) {
                NavigationStack { HowToView() }
            }
            .sheet(item: $selectedDoc) { doc in
                NavigationStack {
                    DocReaderView(doc: doc)
                }
            }
            .alert("Sync error", isPresented: $showSyncAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(docStore.syncError ?? "")
            }
            .onChange(of: docStore.isSyncing) { _, syncing in
                if !syncing, docStore.syncError != nil { showSyncAlert = true }
            }
        }
    }
}

// MARK: - Article row

private struct ArticleRowV2: View {
    let doc: Doc
    @ObservedObject private var favorites = FavoriteStore.shared

    private var isFav: Bool { favorites.isFavorite(id: doc.filename) }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.indigo.opacity(0.1))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.indigo)
                )

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(doc.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Heart
            Button {
                favorites.toggle(item: FavoriteStore.articleItem(from: doc))
            } label: {
                Image(systemName: isFav ? "heart.fill" : "heart")
                    .font(.system(size: 16))
                    .foregroundStyle(isFav ? .red : Color(.tertiaryLabel))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}
