//
//  DocReaderView.swift
//  SDTool
//
//  Created by Saurabh Sharma on 2/28/26.
//

import SwiftUI

struct DocReaderView: View {
    let doc: Doc
    @State private var content: String = ""

    private var scrollKey: String { doc.url.lastPathComponent }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 8) {
                if content.isEmpty {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    ForEach(
                        Array(content.components(separatedBy: "\n").enumerated()),
                        id: \.offset
                    ) { _, line in
                        lineView(for: line)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle(doc.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadContent() }
    }

    @ViewBuilder
    private func lineView(for line: String) -> some View {
        if line.hasPrefix("### ") {
            Text(line.dropFirst(4))
                .font(.title3).bold()
                .padding(.top, 8)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if line.hasPrefix("## ") {
            Text(line.dropFirst(3))
                .font(.title2).bold()
                .padding(.top, 12)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if line.hasPrefix("# ") {
            Text(line.dropFirst(2))
                .font(.title).bold()
                .padding(.top, 16)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if line.hasPrefix("> ") {
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .frame(width: 3)
                    .foregroundStyle(.secondary)
                if let attributed = try? AttributedString(markdown: String(line.dropFirst(2))) {
                    Text(attributed)
                        .font(.body).italic()
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } else {
                    Text(line.dropFirst(2))
                        .font(.body).italic()
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        } else if line.hasPrefix("---") || line.hasPrefix("===") {
            Divider()
                .padding(.vertical, 4)
        } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.body)
                    .padding(.top, 1)
                if let attributed = try? AttributedString(markdown: String(line.dropFirst(2))) {
                    Text(attributed)
                        .font(.body)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                } else {
                    Text(line.dropFirst(2))
                        .font(.body)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
            Color.clear.frame(height: 8)
        } else {
            if let attributed = try? AttributedString(markdown: line) {
                Text(attributed)
                    .font(.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(line)
                    .font(.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func loadContent() {
        let readURL = doc.localURL ?? doc.url
        content = (try? String(contentsOf: readURL, encoding: .utf8))
            ?? "Failed to load document."
        ScrollPositionStore.save(offset: 0, for: scrollKey)
    }
}

#Preview {
    DocReaderView(doc: Doc(name: "Preview", url: URL(fileURLWithPath: "")))
}
