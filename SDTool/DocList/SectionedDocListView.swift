//
//  SectionedDocListView.swift
//  SDTool
//
//  Created by Saurabh Sharma on 3/4/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct SectionedDocListView: View {
    @ObservedObject var docStore: DocStore
    @ObservedObject var sectionStore: DocSectionStore

    // Drag state
    @State private var draggingFilename: String? = nil
    @State private var showAddSection  = false
    @State private var newSectionName  = ""
    @State private var newSectionEmoji = "📁"

    var body: some View {
        List {
            // ── Named sections ─────────────────────────────────────
            ForEach(sectionStore.sections) { section in
                let sectionDocs = sectionStore.docs(in: section, from: docStore.docs)

                Section {
                    if sectionDocs.isEmpty {
                        dropTarget(for: section)
                    } else {
                        ForEach(sectionDocs) { doc in
                            NavigationLink(value: doc) {
                                DocRowView(doc: doc) {
                                    docStore.download(doc)
                                }
                            }
                            // Long-press to start drag
                            .onDrag {
                                draggingFilename = doc.url.lastPathComponent
                                return NSItemProvider(object: doc.url.lastPathComponent as NSString)
                            }
                        }
                        .onMove { from, to in
                            sectionStore.moveDocs(in: section.id, from: from, to: to)
                        }

                        // Drop zone at bottom of non-empty section
                        dropTarget(for: section)
                    }
                } header: {
                    SectionHeader(section: section, sectionStore: sectionStore)
                }
            }
            .onMove(perform: sectionStore.moveSection)
            .onDelete(perform: sectionStore.deleteSection)

            // ── Unsorted docs ──────────────────────────────────────
            let unsorted = sectionStore.unsortedDocs(from: docStore.docs)
            if !unsorted.isEmpty {
                Section {
                    ForEach(unsorted) { doc in
                        NavigationLink(value: doc) {
                            DocRowView(doc: doc) {
                                docStore.download(doc)
                            }
                        }
                        .onDrag {
                            draggingFilename = doc.url.lastPathComponent
                            return NSItemProvider(object: doc.url.lastPathComponent as NSString)
                        }
                    }
                } header: {
                    Text("Unsorted")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // ── Add section button ─────────────────────────────────
            Section {
                Button {
                    showAddSection = true
                } label: {
                    Label("Add Section", systemImage: "plus.circle")
                }
            }
        }
        .listStyle(.insetGrouped)
        .alert("New Section", isPresented: $showAddSection) {
            TextField("Emoji", text: $newSectionEmoji)
            TextField("Section name", text: $newSectionName)
            Button("Add") {
                guard !newSectionName.isEmpty else { return }
                sectionStore.addSection(name: newSectionName, emoji: newSectionEmoji)
                newSectionName  = ""
                newSectionEmoji = "📁"
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Drop target row

    @ViewBuilder
    private func dropTarget(for section: DocSection) -> some View {
        Color.clear
            .frame(height: 36)
            .overlay(
                Text("Drop here to add to \(section.emoji) \(section.name)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            )
            .onDrop(of: [.plainText], isTargeted: nil) { providers in
                providers.first?.loadObject(ofClass: NSString.self) { item, _ in
                    guard let filename = item as? String else { return }
                    DispatchQueue.main.async {
                        sectionStore.move(filename: filename, toSection: section.id)
                        draggingFilename = nil
                    }
                }
                return true
            }
    }
}

// MARK: - Section header with rename support

private struct SectionHeader: View {
    let section: DocSection
    @ObservedObject var sectionStore: DocSectionStore

    @State private var showRename = false
    @State private var editName   = ""
    @State private var editEmoji  = ""

    var body: some View {
        HStack {
            Text("\(section.emoji) \(section.name)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            Spacer()

            Button {
                editName  = section.name
                editEmoji = section.emoji
                showRename = true
            } label: {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .alert("Rename Section", isPresented: $showRename) {
            TextField("Emoji", text: $editEmoji)
            TextField("Name", text: $editName)
            Button("Save") {
                sectionStore.rename(section: section, name: editName, emoji: editEmoji)
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
