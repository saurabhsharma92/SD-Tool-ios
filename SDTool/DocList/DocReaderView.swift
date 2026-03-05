//
//  DocReaderView.swift
//  SDTool
//
//  Created by Saurabh Sharma on 2/28/26.
//

import SwiftUI
import MarkdownUI

struct DocReaderView: View {
    let doc: Doc
    @State private var content: String = ""
    @State private var isLoading = true

    private var scrollKey: String { doc.url.lastPathComponent }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            if isLoading {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            } else {
                Markdown(content)
                    .markdownTheme(.gitHub)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .textSelection(.enabled)
            }
        }
        .navigationTitle(doc.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadContent() }
    }

    private func loadContent() {
        let readURL = doc.localURL ?? doc.url
        content = (try? String(contentsOf: readURL, encoding: .utf8))
            ?? "Failed to load document."
        isLoading = false
        ScrollPositionStore.save(offset: 0, for: scrollKey)
    }
}

#Preview {
    DocReaderView(doc: Doc(name: "Preview", url: URL(fileURLWithPath: "")))
}
