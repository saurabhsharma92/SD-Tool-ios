//
//  DocListView.swift
//  SDTool
//

import SwiftUI

struct DocListView: View {
    @StateObject   private var store        = DocStore()
    @StateObject   private var sectionStore = DocSectionStore()
    @ObservedObject private var router      = NavigationRouter.shared

    @AppStorage(AppSettings.Key.homeViewStyle) private var viewStyle = AppSettings.Default.homeViewStyle

    @State private var navPath      = NavigationPath()
    @State private var showSyncAlert = false

    var body: some View {
        NavigationStack(path: $navPath) {
            Group {
                if store.docs.isEmpty && !store.isSyncing {
                    ContentUnavailableView(
                        "No Articles Found",
                        systemImage: "doc.text",
                        description: Text("Tap ↓ to sync articles from GitHub")
                    )
                } else if viewStyle == "grid" {
                    DocGridView(docStore: store, sectionStore: sectionStore)
                } else {
                    SectionedDocListView(docStore: store, sectionStore: sectionStore)
                }
            }
            .navigationTitle("Articles")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // Activity dial — left side
                ToolbarItem(placement: .topBarLeading) {
                    ActivityDialView(accentColor: .indigo)
                        .frame(width: 32, height: 32)
                }

                // Right side controls
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Grid / List toggle
                    Button {
                        viewStyle = viewStyle == "grid" ? "list" : "grid"
                    } label: {
                        Image(systemName: viewStyle == "grid"
                              ? "list.bullet"
                              : "square.grid.2x2")
                    }

                    // Sync button
                    if store.isSyncing {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button {
                            store.sync()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .onChange(of: store.isSyncing) { syncing in
                if !syncing, let _ = store.syncError { showSyncAlert = true }
            }
            .alert("Sync Error", isPresented: $showSyncAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.syncError ?? "")
            }
            .navigationDestination(for: Doc.self) { doc in
                DocReaderView(doc: doc)
            }
        }
        .onChange(of: router.articleDestination) { dest in
            guard let doc = dest else { return }
            navPath.append(doc)
            router.articleDestination = nil
        }
    }


}

#Preview { DocListView() }
