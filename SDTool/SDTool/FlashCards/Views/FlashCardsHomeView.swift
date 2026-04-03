//
//  FlashCardsHomeView.swift
//  SDTool
//

import SwiftUI

struct FlashCardsHomeView: View {

    @ObservedObject private var store    = FlashCardStore.shared
    @ObservedObject private var progress = FlashCardProgress.shared

    @State private var isSyncing      = false
    @State private var syncMessage:   String? = nil
    @State private var showSyncAlert  = false
    @State private var showContribute = false

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if store.decks.isEmpty {
                    emptyState
                } else {
                    deckGrid
                }
            }
            .navigationTitle("Flash Cards")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showContribute = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 13))
                            Text("Contribute")
                                .font(.system(size: 13))
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    syncButton
                }
            }
            .sheet(isPresented: $showContribute) {
                NavigationStack { HowToView() }
            }
            .alert("Sync Complete", isPresented: $showSyncAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(syncMessage ?? "")
            }
            .navigationDestination(for: FlashDeck.self) { deck in
                StudyView(deck: deck)
            }
        }
    }

    // MARK: - Deck grid

    private var deckGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(store.decks) { deck in
                    NavigationLink(value: deck) {
                        DeckTileView(deck: deck, progress: progress)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("No Flash Card Decks")
                .font(.headline)
            Text("Tap the sync button to download decks from GitHub.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Sync Now") {
                Task { await syncDecks() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sync button

    private var syncButton: some View {
        Button {
            Task { await syncDecks() }
        } label: {
            if isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .disabled(isSyncing)
    }

    // MARK: - Sync

    private func syncDecks() async {
        guard !isSyncing else { return }
        isSyncing = true

        let result = await FlashCardSyncService.shared.sync()

        isSyncing = false

        switch result {
        case .upToDate:
            syncMessage  = "All decks are already up to date."
            showSyncAlert = true
        case .updated(let newDecks, let updatedDecks):
            var parts: [String] = []
            if newDecks     > 0 { parts.append("\(newDecks) new deck\(newDecks > 1 ? "s" : "")") }
            if updatedDecks > 0 { parts.append("\(updatedDecks) updated") }
            syncMessage  = parts.joined(separator: ", ") + " downloaded."
            showSyncAlert = true
        case .failed(let error):
            syncMessage  = error.localizedDescription
            showSyncAlert = true
        }
    }
}
