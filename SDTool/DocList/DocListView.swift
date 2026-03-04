//
//  DocListView.swift
//  SDTool
//
//  Created by Saurabh Sharma on 2/28/26.
//

import SwiftUI

struct DocListView: View {
    @StateObject private var store = DocStore()

    var body: some View {
        NavigationStack {
            Group {
                if store.docs.isEmpty {
                    ContentUnavailableView(
                        "No Docs Found",
                        systemImage: "doc.text",
                        description: Text("Add .md files to SourceDocs.bundle in Xcode")
                    )
                } else {
                    List(store.docs) { doc in
                        NavigationLink(value: doc) {
                            DocRowView(doc: doc) {
                                store.download(doc)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Docs")
            .navigationDestination(for: Doc.self) { doc in
                DocReaderView(doc: doc)
            }
        }
    }
}

// MARK: - DocRowView

struct DocRowView: View {
    let doc: Doc
    let onDownload: () -> Void

    var body: some View {
        HStack {
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
