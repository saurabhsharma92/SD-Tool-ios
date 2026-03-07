//
//  DocListView.swift
//  SDTool
//

import SwiftUI

struct DocListView: View {
    @StateObject private var docStore     = DocStore()
    @StateObject private var sectionStore = DocSectionStore()
    @AppStorage(AppSettings.Key.homeViewStyle) private var homeViewStyle = AppSettings.Default.homeViewStyle

    var body: some View {
        NavigationStack {
            Group {
                if docStore.docs.isEmpty && !docStore.isSyncing {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        // ── Activity dial ──────────────────────────
                        ActivityDialView(accentColor: .indigo)
                            .padding(.top, 12)
                        ActivityDialLegend(accentColor: .indigo)
                            .padding(.top, 6)
                            .padding(.bottom, 8)

                        if homeViewStyle == "tile" {
                            DocGridView(docStore: docStore, sectionStore: sectionStore)
                        } else {
                            SectionedDocListView(docStore: docStore, sectionStore: sectionStore)
                        }
                    }
                }
            }
            .navigationTitle("Articles")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if docStore.isSyncing {
                        ProgressView().scaleEffect(0.8)
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        docStore.sync()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(docStore.isSyncing)

                    Button {
                        homeViewStyle = homeViewStyle == "tile" ? "list" : "tile"
                    } label: {
                        Image(systemName: homeViewStyle == "tile"
                              ? "list.bullet"
                              : "square.grid.2x2")
                    }
                }
            }
            .navigationDestination(for: Doc.self) { doc in
                DocReaderView(doc: doc)
            }
            .alert("Sync Error", isPresented: .constant(docStore.syncError != nil)) {
                Button("OK") { docStore.syncError = nil }
            } message: {
                Text(docStore.syncError ?? "")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("No Articles Yet")
                .font(.headline)
            Text("Tap sync to fetch articles from GitHub.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Sync Now") { docStore.sync() }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - DocRowView (used by SectionedDocListView)

struct DocRowView: View {
    let doc:        Doc
    let onDownload: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(doc.iconColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: doc.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(doc.iconColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.name).font(.headline)
                Text(doc.filename)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !doc.isDownloaded {
                Button(action: onDownload) {
                    Image(systemName: "arrow.down.circle")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview { DocListView() }
