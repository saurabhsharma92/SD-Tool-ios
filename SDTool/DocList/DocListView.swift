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
                if homeViewStyle == "tile" {
                    DocGridView(docStore: docStore, sectionStore: sectionStore)
                } else {
                    SectionedDocListView(docStore: docStore, sectionStore: sectionStore)
                }
            }
            .navigationTitle("Article")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
        }
    }
}

// MARK: - DocRowView

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
                Text(doc.name)
                    .font(.headline)
                Text(doc.url.lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if doc.isDownloaded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
            } else {
                Button(action: onDownload) {
                    Label("Save offline", systemImage: "arrow.down.circle")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    DocListView()
}
