//
//  DocSectionStore.swift
//  SDTool
//
//  Created by Saurabh Sharma on 3/4/26.
//
import SwiftUI
import Foundation
import Combine

class DocSectionStore: ObservableObject {
    @Published var sections: [DocSection] = []

    private let saveKey = "docSections"

    init() {
        load()
    }

    // MARK: - Persistence

    func save() {
        if let data = try? JSONEncoder().encode(sections) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let saved = try? JSONDecoder().decode([DocSection].self, from: data) {
            sections = saved
        } else {
            // First launch — seed defaults
            sections = DocSection.defaults
            save()
        }
    }

    // MARK: - Section management

    func addSection(name: String, emoji: String) {
        sections.append(DocSection(name: name, emoji: emoji))
        save()
    }

    func deleteSection(at offsets: IndexSet) {
        sections.remove(atOffsets: offsets)
        save()
    }

    func moveSection(from source: IndexSet, to destination: Int) {
        sections.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func rename(section: DocSection, name: String, emoji: String) {
        guard let i = sections.firstIndex(where: { $0.id == section.id }) else { return }
        sections[i].name = name
        sections[i].emoji = emoji
        save()
    }

    // MARK: - Doc assignment

    /// Move a doc filename into a target section, removing it from all others.
    func move(filename: String, toSection targetID: UUID) {
        // Remove from every section first
        for i in sections.indices {
            sections[i].docFilenames.removeAll { $0 == filename }
        }
        // Add to target
        if let i = sections.firstIndex(where: { $0.id == targetID }) {
            sections[i].docFilenames.append(filename)
        }
        save()
    }

    /// Remove a doc from whatever section it's in (moves it to Unsorted).
    func removeFromSection(filename: String) {
        for i in sections.indices {
            sections[i].docFilenames.removeAll { $0 == filename }
        }
        save()
    }

    /// Returns the section a doc belongs to, if any.
    func section(for filename: String) -> DocSection? {
        sections.first { $0.docFilenames.contains(filename) }
    }

    /// Docs not assigned to any section.
    func unsortedDocs(from docs: [Doc]) -> [Doc] {
        let assigned = Set(sections.flatMap { $0.docFilenames })
        return docs.filter { !assigned.contains($0.url.lastPathComponent) }
    }

    /// Docs belonging to a given section, in section order.
    func docs(in section: DocSection, from allDocs: [Doc]) -> [Doc] {
        section.docFilenames.compactMap { filename in
            allDocs.first { $0.url.lastPathComponent == filename }
        }
    }

    // MARK: - Reorder docs within a section

    func moveDocs(in sectionID: UUID, from source: IndexSet, to destination: Int) {
        guard let i = sections.firstIndex(where: { $0.id == sectionID }) else { return }
        sections[i].docFilenames.move(fromOffsets: source, toOffset: destination)
        save()
    }
}
