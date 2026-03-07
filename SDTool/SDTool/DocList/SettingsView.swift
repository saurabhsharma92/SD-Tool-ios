//
//  SettingsView.swift
//  SDTool
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.Key.colorScheme)    private var colorScheme    = AppSettings.Default.colorScheme
    @AppStorage(AppSettings.Key.feedCacheHours) private var feedCacheHours = AppSettings.Default.feedCacheHours

    @ObservedObject private var flashStore    = FlashCardStore.shared
    @ObservedObject private var flashProgress = FlashCardProgress.shared

    @State private var showResetAllConfirm   = false
    @State private var deckToReset: FlashDeck? = nil
    @State private var showDeckResetConfirm  = false

    var body: some View {
        NavigationStack {
            Form {

                // ── Appearance ─────────────────────────────────────
                Section("Appearance") {
                    Picker("Theme", selection: $colorScheme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }

                // ── Blogs ──────────────────────────────────────────
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Blog Refresh")
                            Spacer()
                            Text(AppSettings.cacheLabel(for: feedCacheHours))
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                        Slider(value: $feedCacheHours, in: 0...24, step: 0.5)
                            .tint(.accentColor)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Blogs")
                } footer: {
                    Text("How often to refresh blog feeds. Set to 0 to always fetch the latest.")
                }

                // ── Flash Cards ────────────────────────────────────
                Section {
                    ForEach(flashStore.decks) { deck in
                        Button {
                            deckToReset         = deck
                            showDeckResetConfirm = true
                        } label: {
                            HStack {
                                Text(deck.emoji)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Reset \(deck.displayName)")
                                        .foregroundStyle(.primary)
                                    let known = deck.knownCount(progress: flashProgress)
                                    let total = deck.totalCards
                                    Text("\(known) of \(total) cards known")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if deck.knownCount(progress: flashProgress) > 0 {
                                    Image(systemName: "arrow.counterclockwise")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                }
                            }
                        }
                        .disabled(deck.knownCount(progress: flashProgress) == 0)
                    }

                    Button(role: .destructive) {
                        showResetAllConfirm = true
                    } label: {
                        Label("Reset All Progress", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(flashProgress.knownCardKeys.isEmpty)

                } header: {
                    Text("Flash Cards")
                } footer: {
                    Text("Resetting progress marks all cards as unlearned for that deck.")
                }

                // ── About ──────────────────────────────────────────
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build",   value: buildNumber)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Reset \"\(deckToReset?.displayName ?? "")\"?",
                isPresented: $showDeckResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset Progress", role: .destructive) {
                    if let deck = deckToReset { flashProgress.reset(deck: deck) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All cards in this deck will be marked as unlearned.")
            }
            .confirmationDialog(
                "Reset All Flash Card Progress?",
                isPresented: $showResetAllConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset All", role: .destructive) { flashProgress.resetAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All cards across every deck will be marked as unlearned.")
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

#Preview { SettingsView() }
