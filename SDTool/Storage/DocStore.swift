//
//  DocStore.swift
//  SDTool
//
//  Created by Saurabh Sharma on 2/28/26.
//

import Foundation
import Combine

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
