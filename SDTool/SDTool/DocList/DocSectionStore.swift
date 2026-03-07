//
//  DocSectionStore.swift
//  SDTool
//

import Foundation
import Combine
import SwiftUI

class DocSectionStore: ObservableObject {
    @Published var sections: [DocSection] = []

    private let saveKey      = "docSections"
    private let pinnedDocsKey = "pinnedDocFilenames"

    @Published var pinnedDocFilenames: Set<String> = []

    init() { load() }

    // MARK: - Ordered sections for display

    var pinnedSections: [DocSection] {
        sections.filter { $0.isPinned }
    }

    var unpinnedSections: [DocSection] {
        sections.filter { !$0.isPinned }
    }

    // MARK: - Docs in a section
    // Uses doc.filename directly — works for both remote and downloaded docs

    func docs(in section: DocSection, from allDocs: [Doc]) -> [Doc] {
        section.docFilenames.compactMap { filename in
            allDocs.first { $0.filename == filename }
        }
    }

    func unsortedDocs(from allDocs: [Doc]) -> [Doc] {
        let assigned = Set(sections.flatMap { $0.docFilenames })
        return allDocs.filter { !assigned.contains($0.filename) }
    }

    // MARK: - Pin / unpin doc

    func isPinned(doc: Doc) -> Bool {
        pinnedDocFilenames.contains(doc.filename)
    }

    func togglePinDoc(_ doc: Doc) {
        if pinnedDocFilenames.contains(doc.filename) {
            pinnedDocFilenames.remove(doc.filename)
        } else {
            pinnedDocFilenames.insert(doc.filename)
        }
        savePinnedDocs()
    }

    func pinnedDocs(from allDocs: [Doc]) -> [Doc] {
        allDocs.filter { pinnedDocFilenames.contains($0.filename) }
    }

    // MARK: - Move doc to section

    func move(doc: Doc, toSection target: DocSection) {
        // Remove from all sections first
        for i in sections.indices {
            sections[i].docFilenames.removeAll { $0 == doc.filename }
        }
        if let i = sections.firstIndex(where: { $0.id == target.id }) {
            sections[i].docFilenames.append(doc.filename)
        }
        save()
    }

    func removeFromSection(doc: Doc) {
        for i in sections.indices {
            sections[i].docFilenames.removeAll { $0 == doc.filename }
        }
        save()
    }

    // MARK: - Reorder docs within section

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

    // MARK: - Add / rename / delete section

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

    enum SectionDeleteMode {
        case removeFromSectionOnly
        case deleteFilesFromApp
    }

    func delete(section: DocSection, mode: SectionDeleteMode, allDocs: [Doc] = []) {
        guard !section.isDefault else { return }
        if mode == .deleteFilesFromApp {
            for filename in section.docFilenames {
                pinnedDocFilenames.remove(filename)
            }
            savePinnedDocs()
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
            // Migration: wipe any hardcoded bundle filenames from old sections.
            // Old DocSection.defaults had filenames like "chat-system-design.md" baked in.
            // Now filenames in sections are only ones the user manually dragged in.
            let migrationKey = "sectionsFilenamesMigrated_v2"
            if !UserDefaults.standard.bool(forKey: migrationKey) {
                sections = decoded.map { section in
                    var s = section
                    s.docFilenames = []   // clear stale bundle filenames
                    return s
                }
                UserDefaults.standard.set(true, forKey: migrationKey)
                save()
            } else {
                sections = decoded
            }
        } else {
            sections = DocSection.defaults
        }

        if let saved = UserDefaults.standard.stringArray(forKey: pinnedDocsKey) {
            pinnedDocFilenames = Set(saved)
        }
    }
}
