//
//  DocListView.swift
//  SDTool
//
//  Created by Saurabh Sharma on 2/28/26.
//

import SwiftUI
import Combine

// MARK: - Model

struct Doc: Identifiable, Hashable {
    let id: UUID
    let name: String
    let url: URL
    var isDownloaded: Bool
    var localURL: URL?

    init(name: String, url: URL, isDownloaded: Bool = false, localURL: URL? = nil) {
        self.id = UUID()
        self.name = name
        self.url = url
        self.isDownloaded = isDownloaded
        self.localURL = localURL
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Doc, rhs: Doc) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - DocStore (ViewModel)

class DocStore: ObservableObject {
    @Published var docs: [Doc] = []

    private var docsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DownloadedDocs")
    }

    init() {
        try? FileManager.default.createDirectory(
            at: docsDirectory,
            withIntermediateDirectories: true
        )
        loadDocs()
    }

    func loadDocs() {
        guard let bundleURL = Bundle.main.url(forResource: "SourceDocs",
                                              withExtension: "bundle"),
              let docBundle = Bundle(url: bundleURL),
              let urls = docBundle.urls(forResourcesWithExtension: "md",
                                        subdirectory: nil) else {
            print("DocStore: No .md files found in SourceDocs.bundle")
            return
        }

        docs = urls.map { url in
            let filename = url.lastPathComponent
            let localURL = docsDirectory.appendingPathComponent(filename)
            let isDownloaded = FileManager.default.fileExists(atPath: localURL.path)
            let displayName = url.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
            return Doc(
                name: displayName,
                url: url,
                isDownloaded: isDownloaded,
                localURL: isDownloaded ? localURL : nil
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        print("DocStore: Loaded \(docs.count) docs from SourceDocs.bundle")
    }

    func download(_ doc: Doc) {
        guard let index = docs.firstIndex(where: { $0.id == doc.id }) else { return }
        let destination = docsDirectory.appendingPathComponent(doc.url.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: doc.url, to: destination)
            docs[index].isDownloaded = true
            docs[index].localURL = destination
            print("DocStore: Saved to \(destination.path)")
        } catch {
            print("DocStore: Download failed — \(error)")
        }
    }
}

// MARK: - DocListView

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

// MARK: - DocReaderView

struct DocReaderView: View {
    let doc: Doc
    @State private var content: String = ""

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
    }
}

// MARK: - Preview

#Preview {
    DocListView()
}
