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

    // Docs grouped by category
    private var categories: [String] {
        let cats = docStore.docs.map { $0.category }
        var seen = Set<String>()
        return cats.filter { seen.insert($0).inserted }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {

                // ── Pinned Docs ────────────────────────────────────
                let pinned = sectionStore.pinnedDocs(from: docStore.docs)
                    .filter { $0.isDownloaded }
                if !pinned.isEmpty {
                    tileSection(
                        header: {
                            HStack(spacing: 6) {
                                Text("📌")
                                Text("Pinned").font(.headline)
                            }.padding(.horizontal, 4)
                        },
                        docs: pinned, section: nil
                    )
                }

                // ── Pinned Sections ────────────────────────────────
                ForEach(sectionStore.pinnedSections) { section in
                    let docs = sectionStore.docs(in: section, from: docStore.docs)
                    if !docs.isEmpty {
                        tileSection(
                            header: { sectionHeaderView(section) },
                            docs: docs, section: section
                        )
                    }
                }

                // ── Regular Sections ───────────────────────────────
                ForEach(sectionStore.unpinnedSections) { section in
                    let docs = sectionStore.docs(in: section, from: docStore.docs)
                    if !docs.isEmpty {
                        tileSection(
                            header: { sectionHeaderView(section) },
                            docs: docs, section: section
                        )
                    }
                }

                // ── Category groups ────────────────────────────────
                let assignedFilenames = Set(sectionStore.sections.flatMap { $0.docFilenames })
                ForEach(categories, id: \.self) { category in
                    let catDocs = docStore.docs.filter {
                        $0.category == category && !assignedFilenames.contains($0.filename)
                    }
                    if !catDocs.isEmpty {
                        tileSection(
                            header: {
                                Text(category).font(.headline).padding(.horizontal, 4)
                            },
                            docs: catDocs, section: nil
                        )
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .confirmationDialog(
            "Delete \"\(sectionToDelete?.name ?? "")\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Keep docs in category", role: .none) {
                if let s = sectionToDelete {
                    sectionStore.delete(section: s, mode: .removeFromSectionOnly,
                                        allDocs: docStore.docs)
                }
            }
            Button("Delete docs from device", role: .destructive) {
                if let s = sectionToDelete {
                    for filename in s.docFilenames {
                        if let doc = docStore.docs.first(where: { $0.filename == filename }) {
                            docStore.delete(doc)
                        }
                    }
                    sectionStore.delete(section: s, mode: .removeFromSectionOnly,
                                        allDocs: docStore.docs)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("What should happen to the docs inside this section?")
        }
    }

    // MARK: - Tile section

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
                    docTile(doc: doc, section: section)
                }
            }
        }
    }

    // MARK: - Doc tile

    @ViewBuilder
    private func docTile(doc: Doc, section: DocSection?) -> some View {
        switch doc.state {
        case .remote:
            remoteTile(doc: doc)
        case .downloading:
            ZStack {
                DocTileView(doc: doc) {}
                Color.black.opacity(0.3).clipShape(RoundedRectangle(cornerRadius: 14))
                ProgressView().tint(.white)
            }
        case .downloaded:
            NavigationLink(value: doc) {
                DocTileView(doc: doc) { docStore.download(doc) }
            }
            .buttonStyle(.plain)
            .contextMenu { downloadedTileMenu(doc: doc, section: section) }
            .simultaneousGesture(TapGesture().onEnded {
                ActivityStore.shared.recordArticleRead(filename: doc.filename)
            })
        }
    }

    // Remote tile — dimmed with download button
    private func remoteTile(doc: Doc) -> some View {
        ZStack(alignment: .bottomTrailing) {
            DocTileView(doc: doc) {}
                .opacity(0.5)
            Button {
                docStore.download(doc)
            } label: {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.white)
                    .background(Color.accentColor.clipShape(Circle()))
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }

    // MARK: - Section header

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
                Label(section.isPinned ? "Unpin Section" : "Pin Section",
                      systemImage: section.isPinned ? "pin.slash" : "pin")
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

    // MARK: - Downloaded tile context menu

    @ViewBuilder
    private func downloadedTileMenu(doc: Doc, section: DocSection?) -> some View {
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
            if section != nil {
                Divider()
                Button("Move to Category") { sectionStore.removeFromSection(doc: doc) }
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
}
