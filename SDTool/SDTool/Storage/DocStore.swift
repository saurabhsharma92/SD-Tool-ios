//
//  DocStore.swift
//  SDTool
//

import Foundation
import Combine

class DocStore: ObservableObject {
    @Published var docs:       [Doc]   = []
    @Published var isSyncing:  Bool    = false
    @Published var syncError:  String? = nil
    @Published var lastSynced: Date?   = nil

    private let saveKey     = "githubDocs"
    private let syncService = DocSyncService.shared

    init() { load() }

    // MARK: - Sync from GitHub

    func sync() {
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil

        Task {
            do {
                let entries = try await syncService.fetchIndex()

                await MainActor.run {
                    mergeFetchedEntries(entries)
                    lastSynced = Date()
                    isSyncing  = false
                    save()
                }
            } catch {
                await MainActor.run {
                    syncError = error.localizedDescription
                    isSyncing = false
                }
            }
        }
    }

    // MARK: - Download single article

    func download(_ doc: Doc) {
        guard let i = docs.firstIndex(where: { $0.id == doc.id }) else { return }
        docs[i].state = .downloading

        Task {
            do {
                let localURL = try await syncService.download(filename: doc.filename)
                await MainActor.run {
                    if let i = self.docs.firstIndex(where: { $0.id == doc.id }) {
                        self.docs[i].state    = .downloaded
                        self.docs[i].localURL = localURL
                        self.save()
                    }
                }
            } catch {
                await MainActor.run {
                    if let i = self.docs.firstIndex(where: { $0.id == doc.id }) {
                        self.docs[i].state = .remote
                    }
                }
            }
        }
    }

    // MARK: - Delete article from device

    func delete(_ doc: Doc) {
        guard let i = docs.firstIndex(where: { $0.id == doc.id }) else { return }
        try? syncService.deleteLocal(doc.filename)
        docs[i].state    = .remote
        docs[i].localURL = nil
        save()
    }

    // MARK: - Merge index entries with existing docs

    private func mergeFetchedEntries(_ entries: [(filename: String, name: String, category: String)]) {
        var updated: [Doc] = []

        for entry in entries {
            if let existing = docs.first(where: { $0.filename == entry.filename }) {
                // Keep existing state (downloaded stays downloaded)
                var doc = existing
                doc.name     = entry.name      // update name in case index changed
                doc.category = entry.category
                // Re-check if file actually exists on disk
                if doc.state == .downloaded,
                   !syncService.fileExistsLocally(doc.filename) {
                    doc.state    = .remote
                    doc.localURL = nil
                }
                updated.append(doc)
            } else {
                // New article from index
                let localURL = syncService.localURL(for: entry.filename)
                let onDisk   = syncService.fileExistsLocally(entry.filename)
                updated.append(Doc(
                    filename:  entry.filename,
                    name:      entry.name,
                    category:  entry.category,
                    state:     onDisk ? .downloaded : .remote,
                    localURL:  onDisk ? localURL : nil
                ))
            }
        }

        // Keep any locally downloaded docs not in the index (don't silently remove)
        let indexedFilenames = Set(entries.map { $0.filename })
        let orphans = docs.filter {
            $0.state == .downloaded && !indexedFilenames.contains($0.filename)
        }
        updated.append(contentsOf: orphans)

        docs = updated.sorted { $0.name < $1.name }
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(docs) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let saved = try? JSONDecoder().decode([Doc].self, from: data) {
            docs = saved
            // Re-verify downloaded state on disk
            for i in docs.indices where docs[i].state == .downloaded {
                if !syncService.fileExistsLocally(docs[i].filename) {
                    docs[i].state    = .remote
                    docs[i].localURL = nil
                }
            }
        }
    }
}
