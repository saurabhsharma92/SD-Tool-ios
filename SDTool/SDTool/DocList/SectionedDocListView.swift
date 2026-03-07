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

    // Categories derived from synced docs
    private var categories: [String] {
        var seen = Set<String>()
        return docStore.docs
            .map { $0.category }
            .filter { seen.insert($0).inserted }
    }

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
                        Text("Pinned").font(.subheadline.bold())
                    }
                }
            }

            // ── Manual sections (only shown when they have docs) ───
            let filledSections = sectionStore.sections.filter { section in
                !sectionStore.docs(in: section, from: docStore.docs).isEmpty
            }
            ForEach(filledSections) { section in
                sectionBlock(section: section)
            }

            // ── Category groups from GitHub index ──────────────────
            // ALL docs shown here grouped by category from index.md
            // Docs in a manual section get a subtle badge.
            let assignedFilenames = Set(sectionStore.sections.flatMap { $0.docFilenames })

            ForEach(categories, id: \.self) { category in
                let catDocs = docStore.docs.filter { $0.category == category }
                if !catDocs.isEmpty {
                    Section {
                        ForEach(catDocs) { doc in
                            docRow(
                                doc: doc,
                                section: nil,
                                showSectionBadge: assignedFilenames.contains(doc.filename)
                            )
                        }
                    } header: {
                        Text(category).font(.subheadline.bold())
                    }
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
                if let s = sectionToRename, !renameName.isEmpty {
                    sectionStore.rename(section: s, name: renameName, emoji: renameEmoji)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete \"\(sectionToDelete?.name ?? "")\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove section only", role: .none) {
                if let s = sectionToDelete {
                    sectionStore.delete(section: s, mode: .removeFromSectionOnly)
                }
            }
            Button("Delete docs from device", role: .destructive) {
                if let s = sectionToDelete {
                    for filename in s.docFilenames {
                        if let doc = docStore.docs.first(where: { $0.filename == filename }) {
                            docStore.delete(doc)
                        }
                    }
                    sectionStore.delete(section: s, mode: .removeFromSectionOnly)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Docs will still appear in their category group.")
        }
    }

    // MARK: - Manual section block

    @ViewBuilder
    private func sectionBlock(section: DocSection) -> some View {
        let sectionDocs = sectionStore.docs(in: section, from: docStore.docs)
        Section {
            ForEach(sectionDocs) { doc in
                docRow(doc: doc, section: section)
                    .onDrag { NSItemProvider(object: doc.filename as NSString) }
            }
            .onMove { from, to in
                sectionStore.moveDocs(in: section, from: from, to: to)
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
            Text(section.name).font(.subheadline.bold())
            Spacer()
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                sectionStore.togglePin(section: section)
            } label: {
                Label(section.isPinned ? "Unpin Section" : "Pin Section",
                      systemImage: section.isPinned ? "pin.slash" : "pin")
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
                    sectionToDelete   = section
                    showDeleteConfirm  = true
                } label: {
                    Label("Delete Section", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Doc row

    @ViewBuilder
    private func docRow(doc: Doc, section: DocSection?, showSectionBadge: Bool = false) -> some View {
        switch doc.state {
        case .remote:
            remoteDocRow(doc: doc)
        case .downloading:
            HStack {
                docRowContent(doc: doc, showSectionBadge: false)
                Spacer()
                ProgressView().scaleEffect(0.8)
            }
            .padding(.vertical, 2)
        case .downloaded:
            NavigationLink(value: doc) {
                docRowContent(doc: doc, showSectionBadge: showSectionBadge)
            }
            .contextMenu { downloadedContextMenu(doc: doc, section: section) }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    docStore.delete(doc)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .onDrag { NSItemProvider(object: doc.filename as NSString) }
        }
    }

    // Remote row — dimmed with download button
    private func remoteDocRow(doc: Doc) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(doc.iconColor.opacity(0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: doc.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(doc.iconColor.opacity(0.5))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.name)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Not downloaded")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button {
                docStore.download(doc)
            } label: {
                Image(systemName: "arrow.down.circle")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }

    // Downloaded row content
    private func docRowContent(doc: Doc, showSectionBadge: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(doc.iconColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: doc.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(doc.iconColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.name).font(.headline)
                if showSectionBadge,
                   let s = sectionStore.sections.first(where: {
                       $0.docFilenames.contains(doc.filename)
                   }) {
                    Text("\(s.emoji) \(s.name)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    // Context menu for downloaded docs
    @ViewBuilder
    private func downloadedContextMenu(doc: Doc, section: DocSection?) -> some View {
        Button {
            sectionStore.togglePinDoc(doc)
        } label: {
            Label(sectionStore.isPinned(doc: doc) ? "Unpin" : "Pin",
                  systemImage: sectionStore.isPinned(doc: doc) ? "pin.slash" : "pin.fill")
        }
        Menu {
            ForEach(sectionStore.sections) { s in
                Button("\(s.emoji) \(s.name)") {
                    sectionStore.move(doc: doc, toSection: s)
                }
            }
            if sectionStore.sections.contains(where: { $0.docFilenames.contains(doc.filename) }) {
                Divider()
                Button("Remove from Section") {
                    sectionStore.removeFromSection(doc: doc)
                }
            }
        } label: {
            Label("Move to Section", systemImage: "folder")
        }
        Divider()
        Button(role: .destructive) {
            docStore.delete(doc)
        } label: {
            Label("Delete from Device", systemImage: "trash")
        }
    }

    // MARK: - Drop handler

    @discardableResult
    private func handleDrop(providers: [NSItemProvider], toSection: DocSection) -> Bool {
        providers.first?.loadObject(ofClass: NSString.self) { item, _ in
            guard let filename = item as? String else { return }
            DispatchQueue.main.async {
                if let doc = self.docStore.docs.first(where: { $0.filename == filename }) {
                    self.sectionStore.move(doc: doc, toSection: toSection)
                }
            }
        }
        return true
    }
}
