//
//  SettingsView.swift
//  SDTool
//

import SwiftUI

struct SettingsView: View {

    @AppStorage(AppSettings.Key.colorScheme)    private var colorScheme    = AppSettings.Default.colorScheme
    @AppStorage(AppSettings.Key.homeViewStyle)  private var homeViewStyle  = AppSettings.Default.homeViewStyle
    @AppStorage(AppSettings.Key.feedCacheHours) private var feedCacheHours = AppSettings.Default.feedCacheHours

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            List {

                // ── Appearance ────────────────────────────────────────
                Section {
                    Picker(selection: $colorScheme) {
                        Label("System", systemImage: "circle.lefthalf.filled").tag("system")
                        Label("Light",  systemImage: "sun.max").tag("light")
                        Label("Dark",   systemImage: "moon").tag("dark")
                    } label: {
                        Label("Appearance", systemImage: "paintbrush")
                    }
                    .pickerStyle(.navigationLink)
                } header: { Text("Appearance") }

                // ── Home Screen ───────────────────────────────────────
                Section {
                    Picker(selection: $homeViewStyle) {
                        Label("List", systemImage: "list.bullet").tag("list")
                        Label("Tile", systemImage: "square.grid.2x2").tag("tile")
                    } label: {
                        Label("Home Layout", systemImage: "square.grid.2x2")
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("Home Screen")
                } footer: {
                    Text("Choose how documents are displayed on the home screen.")
                }

                // ── Blogs ─────────────────────────────────────────────
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Blog Refresh", systemImage: "arrow.clockwise")
                            Spacer()
                            Text(AppSettings.cacheLabel(for: feedCacheHours))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }

                        Slider(
                            value: $feedCacheHours,
                            in: 0...24,
                            step: 0.5
                        )
                        .tint(Color("AccentColor"))

                        HStack {
                            Text("Always")
                            Spacer()
                            Text("24 hrs")
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Blogs")
                } footer: {
                    Text("How often to fetch new posts. Set to 0 to refresh every time you open a company.")
                }

                // ── About ─────────────────────────────────────────────
                Section(header: Text("About")) {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Documents") {
                        Text("\(documentCount) bundled")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var documentCount: Int {
        Bundle.main.urls(forResourcesWithExtension: "md", subdirectory: nil)?.count ?? 0
    }
}

#Preview {
    SettingsView()
}
