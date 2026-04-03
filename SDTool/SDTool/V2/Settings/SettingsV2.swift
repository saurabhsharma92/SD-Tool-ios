//
//  SettingsV2.swift
//  SDTool
//
//  Settings screen for the v2 redesign.
//  Reuses existing sub-views (AccountView, FlashCardSettingsView etc.)
//  Adds: Company blog management, custom RSS feeds, Privacy section.
//

import SwiftUI
import FirebaseAuth

struct SettingsV2: View {
    @AppStorage(AppSettings.Key.geminiModel)     private var geminiModel   = AppSettings.Default.geminiModel
    @AppStorage(AppSettings.Key.colorScheme)     private var colorScheme   = AppSettings.Default.colorScheme
    @AppStorage(AppSettings.Key.faceIDEnabled)   private var faceIDEnabled = AppSettings.Default.faceIDEnabled
    @AppStorage(AppSettings.Key.appFont)         private var appFont       = AppSettings.Default.appFont
    @AppStorage(AppSettings.Key.fontSize)        private var fontSize      = AppSettings.Default.fontSize
    @ObservedObject private var biometric    = BiometricService.shared
    @ObservedObject private var visibility   = CompanyVisibilityStore.shared
    @ObservedObject private var quotaStore   = AIQuotaStore.shared
    @ObservedObject private var authStore    = AuthStore.shared

    @State private var showAddFeed      = false
    @State private var showDeleteAlert  = false
    @State private var showPrivacy      = false

    private var appVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—" }
    private var buildNumber: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—" }

    var body: some View {
        NavigationStack {
            Form {

                // ── Account ───────────────────────────────────────
                Section {
                    NavigationLink(destination: AccountView()) {
                        AccountRowView()
                    }
                }

                // ── Blogs ─────────────────────────────────────────
                Section {
                    NavigationLink(destination: BlogManagementView()) {
                        Label("Blogs", systemImage: "newspaper.fill")
                    }
                    NavigationLink(destination: CustomFeedsManagementView()) {
                        Label("Custom RSS Feed", systemImage: "dot.radiowaves.left.and.right")
                    }
                } header: {
                    Text("Content")
                } footer: {
                    Text("Toggle which company blogs appear as tabs on the Home screen.")
                }

                // ── Flash Cards ───────────────────────────────────
                Section("Study") {
                    NavigationLink(destination: FlashCardSettingsView()) {
                        Label("Flash Cards", systemImage: "rectangle.stack.fill")
                    }
                }

                // ── Security ──────────────────────────────────────
                Section("Security") {
                    Toggle(isOn: $faceIDEnabled) {
                        Label(biometric.biometricLabel, systemImage: biometric.biometricIcon)
                    }
                    .tint(.indigo)
                }

                // ── Appearance ────────────────────────────────────
                Section("Appearance") {
                    Picker("Theme", selection: $colorScheme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)

                    Picker("Font", selection: $appFont) {
                        ForEach(AppSettings.AppFont.allCases, id: \.rawValue) { f in
                            Text(f.label).tag(f.rawValue as String)
                        }
                    }

                    HStack {
                        Text("Text size")
                        Slider(value: $fontSize, in: 0.8...1.4, step: 0.1)
                        Text("\(Int((fontSize * 100).rounded()))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 36)
                    }
                }

                // ── AI Model ──────────────────────────────────────
                Section("AI") {
                    NavigationLink(destination: AIModelSettingsView()) {
                        HStack {
                            Label("Model", systemImage: "sparkles")
                            Spacer()
                            Text(AppSettings.GeminiModel(rawValue: geminiModel)?.shortLabel ?? geminiModel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink(destination: AIQuotaDetailView()) {
                        HStack {
                            Label("Usage Today", systemImage: "chart.bar.fill")
                            Spacer()
                            let model  = AppSettings.GeminiModel(rawValue: geminiModel) ?? .flashLite
                            let used   = quotaStore.usedToday
                            let limit  = model.dailyLimit
                            Text("\(used) / \(limit)")
                                .font(.subheadline)
                                .foregroundStyle(quotaStore.isExhausted ? .red : .secondary)
                        }
                    }
                }

                // ── Privacy ───────────────────────────────────────
                Section("Privacy") {
                    Button {
                        showPrivacy = true
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                            .foregroundStyle(.primary)
                    }

                    Button {
                        AIQuotaStore.shared.reset()
                    } label: {
                        Label("Reset AI Usage Data", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(.primary)
                    }

                    if authStore.isSignedIn && !authStore.isGuest {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Delete Account", systemImage: "person.fill.xmark")
                        }
                    }
                }

                // ── About ─────────────────────────────────────────
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build",   value: buildNumber)
                    LabeledContent("Model",   value: AppSettings.GeminiModel(rawValue: geminiModel)?.label ?? geminiModel)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPrivacy) {
                PrivacyConsentView(onAccept: { showPrivacy = false })
            }
            .alert("Delete account?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    Task { try? await authStore.deleteAccount() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes your account and all data. This cannot be undone.")
            }
        }
    }
}

// MARK: - Blog management (company toggles)

struct BlogManagementView: View {
    @ObservedObject private var blogStore  = BlogStore.shared
    @ObservedObject private var visibility = CompanyVisibilityStore.shared

    var body: some View {
        List {
            Section {
                ForEach(blogStore.companies.sorted { $0.name < $1.name }) { company in
                    CompanyToggleRow(company: company)
                }
            } header: {
                Text("Show on Home tab")
            } footer: {
                Text("Disabled companies are hidden from the Home tab strip. Their data is not deleted.")
            }
        }
        .navigationTitle("Company blogs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CompanyToggleRow: View {
    let company: BlogCompany
    @ObservedObject private var visibility = CompanyVisibilityStore.shared

    private var isEnabled: Bool { visibility.isEnabled(company.name) }
    private var isPinned:  Bool { visibility.isPinned(company.name) }

    var body: some View {
        HStack(spacing: 12) {
            // Favicon / emoji
            FaviconView(domain: company.faviconDomain, fallback: company.emoji, size: 28)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(company.name)
                    .font(.subheadline.weight(.medium))
                Text(company.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Pin button
            Button {
                visibility.togglePin(company.name)
            } label: {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 14))
                    .foregroundStyle(isPinned ? .indigo : Color(.tertiaryLabel))
            }
            .buttonStyle(.plain)

            // Enable toggle
            Toggle("", isOn: Binding(
                get:  { isEnabled },
                set:  { visibility.setEnabled(company.name, enabled: $0) }
            ))
            .tint(.indigo)
            .labelsHidden()
            .frame(width: 52)
        }
        .opacity(isEnabled ? 1 : 0.5)
    }
}

// MARK: - Custom feeds management

struct CustomFeedsManagementView: View {
    @ObservedObject private var visibility = CompanyVisibilityStore.shared
    @State private var showAddFeed = false

    var body: some View {
        List {
            Section {
                ForEach(visibility.customFeeds) { feed in
                    HStack {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feed.displayName)
                                .font(.subheadline.weight(.medium))
                            Text(feed.feedURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .onDelete { offsets in
                    offsets.forEach { visibility.removeFeed(id: visibility.customFeeds[$0].id) }
                }

                Button {
                    showAddFeed = true
                } label: {
                    Label("Add custom feed", systemImage: "plus.circle.fill")
                        .foregroundStyle(.indigo)
                }
            } header: {
                Text("Custom RSS feeds")
            } footer: {
                Text("Each custom feed appears as its own tab on the Home screen. Swipe left to delete.")
            }
        }
        .navigationTitle("Custom feeds")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .sheet(isPresented: $showAddFeed) {
            RSSFeedSheet()
        }
    }
}

// MARK: - AI Model settings (reuse from SettingsView)

struct AIModelSettingsView: View {
    @AppStorage(AppSettings.Key.geminiModel) private var geminiModel = AppSettings.Default.geminiModel

    var body: some View {
        Form {
            Section {
                Picker("Gemini model", selection: $geminiModel) {
                    ForEach(AppSettings.GeminiModel.allCases, id: \.rawValue) { m in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.label)
                            Text(m.enablementNote)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(m.rawValue)
                    }
                }
                .pickerStyle(.inline)
            } header: {
                Text("Model")
            } footer: {
                Text("All models are free on Firebase AI Logic. Daily quota is shared across all users of this app.")
            }

            Section("Today's usage") {
                AIQuotaBadge(expanded: true)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .navigationTitle("AI model")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - AI Quota detail

struct AIQuotaDetailView: View {
    var body: some View {
        Form {
            Section {
                AIQuotaBadge(expanded: true)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            Section {
                Button(role: .destructive) {
                    AIQuotaStore.shared.reset()
                } label: {
                    Text("Reset usage count")
                }
            } footer: {
                Text("Only resets your local device count. Does not affect the shared project quota.")
            }
        }
        .navigationTitle("AI usage")
        .navigationBarTitleDisplayMode(.inline)
    }
}
