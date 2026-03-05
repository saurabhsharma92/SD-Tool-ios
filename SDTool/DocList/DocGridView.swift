//
//  DocGridView.swift
//  SDTool
//
//  Created by Saurabh Sharma on 3/4/26.
//

import SwiftUI

struct DocGridView: View {
    @ObservedObject var store: DocStore

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            if store.docs.isEmpty {
                ContentUnavailableView(
                    "No Docs Found",
                    systemImage: "doc.text",
                    description: Text("Add .md files to SourceDocs.bundle in Xcode")
                )
                .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(store.docs) { doc in
                        NavigationLink(value: doc) {
                            DocTileView(doc: doc) {
                                store.download(doc)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}
