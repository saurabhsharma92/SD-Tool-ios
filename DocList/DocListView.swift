//
//  DocListView.swift
//  SDTool
//
//  Created by Saurabh Sharma on 2/28/26.
//

import SwiftUI

struct DocListView: View {
    private let entries = DocListViewModel.documentEntries

    var body: some View {
        NavigationStack {
            List {
                ForEach(entries, id: \.docId) { entry in
                    NavigationLink(destination: DocReaderView(docId: entry.docId, displayName: entry.displayName).id(entry.docId)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.displayName)
                                .font(.headline)
                            Text("Tap to read")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Docs")
            .listStyle(.insetGrouped)
        }
    }
}

#Preview {
    DocListView()
}
