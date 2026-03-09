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
                    VStack(spacing: 0) {
                        ActivityDialView(accentColor: .indigo)
                            .padding(.top, 8)
                        ContentUnavailableView(
                            "No Articles Found",
                            systemImage: "doc.text",
                            description: Text("Tap ↓ to sync articles from GitHub")
                        )
                    }
                } else if viewStyle == "grid" {
                    DocGridView(docStore: store, sectionStore: sectionStore)
                        .safeAreaInset(edge: .top, spacing: 0) {
                            ActivityDialView(accentColor: .indigo)
                                .padding(.top, 8)
                        }
                } else {
                    SectionedDocListView(docStore: store, sectionStore: sectionStore)
                        .safeAreaInset(edge: .top, spacing: 0) {
                            ActivityDialView(accentColor: .indigo)
                                .padding(.top, 8)
                        }
                }
            }
            .navigationTitle("Articles")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                // AI quota pill — centre of toolbar
                ToolbarItem(placement: .bottomBar) {
                    AIQuotaBadge()
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
            .onChange(of: store.isSyncing) { _, syncing in
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
        .onChange(of: router.articleDestination) { _, dest in
            guard let doc = dest else { return }
            navPath.append(doc)
            router.articleDestination = nil
        }
    }


}

#Preview { DocListView() }
