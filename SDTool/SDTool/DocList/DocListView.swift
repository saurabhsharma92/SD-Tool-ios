//
//  DocListView.swift
//  SDTool
//

import SwiftUI

struct DocListView: View {
    @StateObject  private var store        = DocStore()
    @StateObject  private var sectionStore = DocSectionStore()
    @ObservedObject private var router     = NavigationRouter.shared

    // Local navigation path — driven by router.articleDestination
    @State private var navPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navPath) {
            VStack {
                if store.docs.isEmpty {
                    ContentUnavailableView(
                        "No Articles Found",
                        systemImage: "doc.text",
                        description: Text("Sync articles from the toolbar")
                    )
                } else {
                    SectionedDocListView(docStore: store, sectionStore: sectionStore)
                }
            }
            .navigationDestination(for: Doc.self) { doc in
                DocReaderView(doc: doc)
            }
        }
        // When router pushes an article destination, navigate to it
        .onChange(of: router.articleDestination) { dest in
            guard let doc = dest else { return }
            navPath.append(doc)
            router.articleDestination = nil   // consume
        }
    }
}

#Preview { DocListView() }
