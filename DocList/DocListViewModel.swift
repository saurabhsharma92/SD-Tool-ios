//
//  DocListViewModel.swift
//  SDTool
//
//  Created by Saurabh Sharma on 2/28/26.
//

import Foundation

/// Provides the list of document identifiers and display names from the app bundle (Option B: .md.gz in Docs).
struct DocListViewModel {
    private static let docsSubdirectory = "Docs"
    private static let resourceExtension = "gz"

    /// Pairs of (displayName, docId) for each doc. docId is the filename used to load from Bundle (e.g. "cache_system_design.md.gz").
    static var documentEntries: [(displayName: String, docId: String)] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: Self.resourceExtension, subdirectory: Self.docsSubdirectory) else {
            return []
        }
        return urls
            .map { url in
                let docId = url.lastPathComponent
                let nameWithoutGz = (docId as NSString).deletingPathExtension
                let displayName = nameWithoutGz
                    .replacingOccurrences(of: ".md", with: "")
                    .replacingOccurrences(of: "_", with: " ")
                return (displayName: displayName, docId: docId)
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
