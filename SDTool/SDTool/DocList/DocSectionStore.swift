//
//  DocSectionStore.swift
//  SDTool
//

import Foundation
import Combine
import SwiftUI

class DocSectionStore: ObservableObject {
    @Published var sections:           [DocSection] = []
    @Published var pinnedDocFilenames: Set<String>  = []

    private let saveKey       = "docSections"
    private let pinnedDocsKey = "pinnedDocFilenames"

    init() { load() }

    // MARK: - Ordered sections

    var pinnedSections: [DocSection] {
        sections.filter { $0.isPinned }
    }

    var unpinnedSections: [DocSection] {
        sections.filter { !$0.isPinned }
    }

    // MARK: - Docs in a section

    func docs(in section: DocSection, from allDocs: [Doc]) -> [Doc] {
        section.docFilenames.compactMap { filename in
            allDocs.first { $0.url.lastPathComponent == filename }
        }
    }

    func unsortedDocs(from allDocs: [Doc]) -> [Doc] {
        let assigned = Set(sections.flatMap { $0.docFilenames })
        return allDocs.filter { !assigned.contains($0.url.lastPathComponent) }
    }

    // MARK: - Pin / unpin doc

    func isPinned(doc: Doc) -> Bool {
        pinnedDocFilenames.contains(doc.url.lastPathComponent)
    }

    func togglePinDoc(_ doc: Doc) {
        let filename = doc.url.lastPathComponent
        if pinnedDocFilenames.contains(filename) {
            pinnedDocFilenames.remove(filename)
        } else {
            pinnedDocFilenames.insert(filename)
        }
        savePinnedDocs()
    }

    func pinnedDocs(from allDocs: [Doc]) -> [Doc] {
        allDocs.filter { pinnedDocFilenames.contains($0.url.lastPathComponent) }
    }

    // MARK: - Move doc to section

    func move(doc: Doc, toSection target: DocSection) {
        let filename = doc.url.lastPathComponent
        for i in sections.indices {
            sections[i].docFilenames.removeAll { $0 == filename }
        }
        if let i = sections.firstIndex(where: { $0.id == target.id }) {
            sections[i].docFilenames.append(filename)
        }
        save()
    }

    func removeFromSection(doc: Doc) {
        let filename = doc.url.lastPathComponent
        for i in sections.indices {
            sections[i].docFilenames.removeAll { $0 == filename }
        }
        save()
    }

    func moveDocs(in section: DocSection, from source: IndexSet, to destination: Int) {
        guard let i = sections.firstIndex(where: { $0.id == section.id }) else { return }
        sections[i].docFilenames.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // MARK: - Pin / unpin section

    func togglePin(section: DocSection) {
        guard let i = sections.firstIndex(where: { $0.id == section.id }) else { return }
        sections[i].isPinned.toggle()
        save()
    }

    // MARK: - Add / rename section

    func addSection(name: String, emoji: String) {
        sections.append(DocSection(name: name, emoji: emoji))
        save()
    }

    func rename(section: DocSection, name: String, emoji: String) {
        guard let i = sections.firstIndex(where: { $0.id == section.id }) else { return }
        sections[i].name  = name
        sections[i].emoji = emoji
        save()
    }

    // MARK: - Delete section

    enum SectionDeleteMode {
        case removeFromSectionOnly   // docs move to Unsorted
        case deleteFilesFromDevice   // .md files permanently deleted from disk
    }

    /// Deletes a user-created section.
    /// - `deleteFilesFromDevice`: removes the actual .md file from the app's
    ///   Documents/cache directory. Bundled read-only files cannot be deleted
    ///   but are removed from all tracking (pinned, sections).
    func delete(section: DocSection, mode: SectionDeleteMode, allDocs: [Doc]) {
        guard !section.isDefault else { return }

        if mode == .deleteFilesFromDevice {
            let filesToDelete = section.docFilenames
            let fm = FileManager.default

            for filename in filesToDelete {
                // Remove from pinned tracking
                pinnedDocFilenames.remove(filename)

                // Try to find and delete the actual file
                if let doc = allDocs.first(where: { $0.url.lastPathComponent == filename }) {
                    // Delete local/downloaded copy if it exists
                    if let localURL = doc.localURL, fm.fileExists(atPath: localURL.path) {
                        try? fm.removeItem(at: localURL)
                    }
                    // Also attempt to delete if it's in a writable location
                    // (bundled files in .app are read-only — deletion silently fails, which is safe)
                    if fm.fileExists(atPath: doc.url.path) {
                        try? fm.removeItem(at: doc.url)
                    }
                }
            }
            savePinnedDocs()
        }

        // Remove section from all other sections' doc lists too
        let filenames = Set(section.docFilenames)
        for i in sections.indices {
            sections[i].docFilenames.removeAll { filenames.contains($0) }
        }

        sections.removeAll { $0.id == section.id }
        save()
    }

    // MARK: - Reorder sections

    func moveSections(from source: IndexSet, to destination: Int) {
        sections.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // MARK: - Persistence

    func save() {
        guard let data = try? JSONEncoder().encode(sections) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    private func savePinnedDocs() {
        UserDefaults.standard.set(Array(pinnedDocFilenames), forKey: pinnedDocsKey)
    }

    private func load() {
        if let data    = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([DocSection].self, from: data) {
            sections = decoded
        } else {
            sections = DocSection.defaults
        }
        if let saved = UserDefaults.standard.stringArray(forKey: pinnedDocsKey) {
            pinnedDocFilenames = Set(saved)
        }
    }
}
