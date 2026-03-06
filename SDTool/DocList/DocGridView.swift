//
//  DocGridView.swift
//  SDTool
//
//  Created by Saurabh Sharma on 3/4/26.
//

import SwiftUI

struct DocGridView: View {
    @ObservedObject var docStore:     DocStore
    @ObservedObject var sectionStore: DocSectionStore

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {

                // ── Named sections ─────────────────────────────────
                ForEach(sectionStore.sections) { section in
                    let sectionDocs = sectionStore.docs(in: section, from: docStore.docs)
                    if !sectionDocs.isEmpty {
                        sectionBlock(title: "\(section.emoji) \(section.name)",
                                     docs: sectionDocs)
                    }
                }

                // ── Unsorted ───────────────────────────────────────
                let unsorted = sectionStore.unsortedDocs(from: docStore.docs)
                if !unsorted.isEmpty {
                    sectionBlock(title: "Unsorted", docs: unsorted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Section block

    @ViewBuilder
    private func sectionBlock(title: String, docs: [Doc]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(docs) { doc in
                    NavigationLink(value: doc) {
                        DocTileView(doc: doc) {
                            docStore.download(doc)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
