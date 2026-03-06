//
//  DocGridView.swift
//  SDTool
//

import SwiftUI

struct DocGridView: View {
    @ObservedObject var docStore:     DocStore
    @ObservedObject var sectionStore: DocSectionStore

    @State private var sectionToDelete:  DocSection? = nil
    @State private var showDeleteConfirm = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {

                // ── Pinned Docs ────────────────────────────────────
                let pinned = sectionStore.pinnedDocs(from: docStore.docs)
                if !pinned.isEmpty {
                    tileSection(
                        header: {
                            HStack(spacing: 6) {
                                Text("📌")
                                Text("Pinned").font(.headline)
                            }
                            .padding(.horizontal, 4)
                        },
                        docs:    pinned,
                        section: nil
                    )
                }

                // ── Pinned Sections ────────────────────────────────
                ForEach(sectionStore.pinnedSections) { section in
                    let docs = sectionStore.docs(in: section, from: docStore.docs)
                    if !docs.isEmpty {
                        tileSection(
                            header: { sectionHeaderView(section) },
                            docs:   docs,
                            section: section
                        )
                    }
                }

                // ── Regular Sections ───────────────────────────────
                ForEach(sectionStore.unpinnedSections) { section in
                    let docs = sectionStore.docs(in: section, from: docStore.docs)
                    if !docs.isEmpty {
                        tileSection(
                            header: { sectionHeaderView(section) },
                            docs:   docs,
                            section: section
                        )
                    }
                }

                // ── Unsorted ───────────────────────────────────────
                let unsorted = sectionStore.unsortedDocs(from: docStore.docs)
                if !unsorted.isEmpty {
                    tileSection(
                        header: {
                            Text("Unsorted")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                        },
                        docs:    unsorted,
                        section: nil
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
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

    // MARK: - Tile section block

    @ViewBuilder
    private func tileSection<Header: View>(
        header:  @escaping () -> Header,
        docs:    [Doc],
        section: DocSection?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            header()
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(docs) { doc in
                    NavigationLink(value: doc) {
                        DocTileView(doc: doc) { docStore.download(doc) }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        docContextMenu(doc: doc, section: section)
                    }
                }
            }
        }
    }

    // MARK: - Section header with context menu

    private func sectionHeaderView(_ section: DocSection) -> some View {
        HStack(spacing: 4) {
            Text(section.isPinned ? "📌" : section.emoji)
            Text(section.name).font(.headline)
            Spacer()
        }
        .padding(.horizontal, 4)
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
}
