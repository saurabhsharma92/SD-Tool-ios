//
//  SectionedDocListView.swift
//  SDTool
//

import SwiftUI
import UniformTypeIdentifiers

struct SectionedDocListView: View {
    @ObservedObject var docStore:     DocStore
    @ObservedObject var sectionStore: DocSectionStore

    @State private var showAddSection    = false
    @State private var newSectionName    = ""
    @State private var newSectionEmoji   = "📁"
    @State private var sectionToDelete:  DocSection? = nil
    @State private var showDeleteConfirm = false
    @State private var sectionToRename:  DocSection? = nil
    @State private var renameName        = ""
    @State private var renameEmoji       = ""
    @State private var showRenameSheet   = false

    var body: some View {
        List {

            // ── Pinned Docs ────────────────────────────────────────
            let pinned = sectionStore.pinnedDocs(from: docStore.docs)
            if !pinned.isEmpty {
                Section {
                    ForEach(pinned) { doc in
                        docRow(doc: doc, section: nil)
                    }
                } header: {
                    HStack(spacing: 4) {
                        Text("📌")
                        Text("Pinned")
                            .font(.subheadline.bold())
                    }
                }
            }

            // ── Pinned Sections ────────────────────────────────────
            ForEach(sectionStore.pinnedSections) { section in
                sectionBlock(section: section)
            }

            // ── Regular Sections ───────────────────────────────────
            ForEach(sectionStore.unpinnedSections) { section in
                sectionBlock(section: section)
            }

            // ── Unsorted ───────────────────────────────────────────
            let unsorted = sectionStore.unsortedDocs(from: docStore.docs)
            if !unsorted.isEmpty {
                Section {
                    ForEach(unsorted) { doc in
                        docRow(doc: doc, section: nil)
                    }
                } header: {
                    Text("Unsorted")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }
            }

            // ── Add Section ────────────────────────────────────────
            Section {
                Button {
                    newSectionName  = ""
                    newSectionEmoji = "📁"
                    showAddSection  = true
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
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename Section", isPresented: $showRenameSheet) {
            TextField("Emoji", text: $renameEmoji)
            TextField("Section name", text: $renameName)
            Button("Save") {
                if let section = sectionToRename, !renameName.isEmpty {
                    sectionStore.rename(section: section, name: renameName, emoji: renameEmoji)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete \"\(sectionToDelete?.name ?? "")\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Keep docs in Unsorted", role: .none) {
                if let s = sectionToDelete {
                    sectionStore.delete(section: s, mode: .removeFromSectionOnly,
                                        allDocs: docStore.docs)
                }
            }
            Button("Delete docs from device permanently", role: .destructive) {
                if let s = sectionToDelete {
                    sectionStore.delete(section: s, mode: .deleteFilesFromDevice,
                                        allDocs: docStore.docs)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("What should happen to the docs inside this section?")
        }
    }

    // MARK: - Section block

    @ViewBuilder
    private func sectionBlock(section: DocSection) -> some View {
        let sectionDocs = sectionStore.docs(in: section, from: docStore.docs)
        Section {
            ForEach(sectionDocs) { doc in
                docRow(doc: doc, section: section)
                    .onDrag {
                        NSItemProvider(object: doc.url.lastPathComponent as NSString)
                    }
            }
            .onMove { from, to in
                sectionStore.moveDocs(in: section, from: from, to: to)
            }

            // Drop target at bottom of each section
            Color.clear
                .frame(height: 4)
                .listRowBackground(Color.clear)
                .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
                    handleDrop(providers: providers, toSection: section)
                }
        } header: {
            sectionHeader(section: section)
        }
        .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
            handleDrop(providers: providers, toSection: section)
        }
    }

    // MARK: - Section header

    private func sectionHeader(section: DocSection) -> some View {
        HStack(spacing: 4) {
            Text(section.isPinned ? "📌" : section.emoji)
            Text(section.name)
                .font(.subheadline.bold())
            Spacer()
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                sectionStore.togglePin(section: section)
            } label: {
                Label(
                    section.isPinned ? "Unpin Section" : "Pin Section",
                    systemImage: section.isPinned ? "pin.slash" : "pin"
                )
            }

            Button {
                sectionToRename = section
                renameName      = section.name
                renameEmoji     = section.emoji
                showRenameSheet = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            if !section.isDefault {
                Divider()
                Button(role: .destructive) {
                    sectionToDelete  = section
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Section", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Doc row

    private func docRow(doc: Doc, section: DocSection?) -> some View {
        NavigationLink(value: doc) {
            DocRowView(doc: doc) { docStore.download(doc) }
        }
        .contextMenu {
            docContextMenu(doc: doc, section: section)
        }
        .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
            guard let section else { return false }
            return handleDrop(providers: providers, toSection: section)
        }
    }

    // MARK: - Doc context menu

    @ViewBuilder
    private func docContextMenu(doc: Doc, section: DocSection?) -> some View {
        Button {
            sectionStore.togglePinDoc(doc)
        } label: {
            Label(
                sectionStore.isPinned(doc: doc) ? "Unpin" : "Pin",
                systemImage: sectionStore.isPinned(doc: doc) ? "pin.slash" : "pin.fill"
            )
        }

        Menu {
            ForEach(sectionStore.sections) { s in
                Button("\(s.emoji) \(s.name)") {
                    sectionStore.move(doc: doc, toSection: s)
                }
            }
            if section != nil {
                Divider()
                Button("Move to Unsorted") {
                    sectionStore.removeFromSection(doc: doc)
                }
            }
        } label: {
            Label("Move to Section", systemImage: "folder")
        }

        if section != nil {
            Divider()
            Button(role: .destructive) {
                sectionStore.removeFromSection(doc: doc)
            } label: {
                Label("Remove from Section", systemImage: "minus.circle")
            }
        }
    }

    // MARK: - Drop handler

    @discardableResult
    private func handleDrop(providers: [NSItemProvider], toSection: DocSection) -> Bool {
        providers.first?.loadObject(ofClass: NSString.self) { item, _ in
            guard let filename = item as? String else { return }
            DispatchQueue.main.async {
                if let doc = docStore.docs.first(where: {
                    $0.url.lastPathComponent == filename
                }) {
                    sectionStore.move(doc: doc, toSection: toSection)
                }
            }
        }
        return true
    }
}
