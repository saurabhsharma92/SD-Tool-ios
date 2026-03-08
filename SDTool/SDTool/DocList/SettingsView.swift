//
//  SettingsView.swift
//  SDTool
//

import SwiftUI
import FirebaseAuth

// MARK: - Root Settings

struct SettingsView: View {
    @AppStorage(AppSettings.Key.colorScheme)   private var colorScheme   = AppSettings.Default.colorScheme
    @AppStorage(AppSettings.Key.faceIDEnabled) private var faceIDEnabled = AppSettings.Default.faceIDEnabled
    @AppStorage(AppSettings.Key.appFont)       private var appFont       = AppSettings.Default.appFont
    @ObservedObject private var biometric = BiometricService.shared

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        NavigationStack {
            Form {

                // ── Profile / Account ──────────────────────────────
                Section {
                    NavigationLink(destination: AccountView()) {
                        AccountRowView()
                    }
                }

                // ── Feature Settings ───────────────────────────────
                Section("Feature Settings") {
                    NavigationLink(destination: ArticleSettingsView()) {
                        Label("Articles", systemImage: "text.book.closed.fill")
                    }
                    NavigationLink(destination: BlogSettingsView()) {
                        Label("Blogs", systemImage: "newspaper.fill")
                    }
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
                    .onChange(of: faceIDEnabled) { enabled in
                        if enabled {
                            // Verify they can actually authenticate before enabling
                            Task { await biometric.authenticate() }
                        }
                    }
                }

                // ── Appearance ─────────────────────────────────────
                Section("Appearance") {
                    Picker("Theme", selection: $colorScheme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)

                    Picker("Font", selection: $appFont) {
                        ForEach(AppSettings.AppFont.allCases, id: \.rawValue) { font in
                            Text(font.label).tag(font.rawValue)
                        }
                    }
                }

                // ── About ──────────────────────────────────────────
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build",   value: buildNumber)
                    LabeledContent("Model",   value: "Gemini 2.5 Flash Lite")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Account Row (used in Settings root)

struct AccountRowView: View {
    @ObservedObject private var authStore = AuthStore.shared

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(authStore.displayName)
                    .font(.headline)
                Text(authStore.email.isEmpty ? "Signed in" : authStore.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Avatar View

struct AvatarView: View {
    @ObservedObject private var authStore = AuthStore.shared
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [.indigo, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing))
                .frame(width: size, height: size)

            if let url = authStore.photoURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialsView
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                initialsView
            }
        }
    }

    private var initialsView: some View {
        Text(authStore.initials)
            .font(.system(size: size * 0.32, weight: .bold))
            .foregroundStyle(.white)
    }
}

// MARK: - Account Page

struct AccountView: View {
    @ObservedObject private var authStore     = AuthStore.shared
    @ObservedObject private var progressStore = ReadingProgressStore.shared
    @ObservedObject private var likedStore    = LikedPostsStore.shared
    @ObservedObject private var flashProgress = FlashCardProgress.shared
    @ObservedObject private var activityStore = ActivityStore.shared
    @StateObject   private var docStore       = DocStore()

    @State private var showClearConfirm  = false
    @State private var showSignOutConfirm = false

    var body: some View {
        Form {
            // ── Profile ───────────────────────────────────────────
            Section {
                HStack(spacing: 16) {
                    AvatarView(size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(authStore.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)
                        if !authStore.email.isEmpty {
                            Text(authStore.email)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        // Provider badge
                        let provider = authStore.user?.providerData.first?.providerID ?? ""
                        Label(providerLabel(provider),
                              systemImage: providerIcon(provider))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            // ── Reading Stats ──────────────────────────────────────
            Section("Reading Stats") {
                LabeledContent("Articles Available",  value: "\(docStore.docs.count)")
                LabeledContent("In Progress",         value: "\(progressStore.inProgress.count)")
                LabeledContent("Completed",           value: "\(progressStore.completed.count)")
                LabeledContent("Liked Blog Posts",    value: "\(likedStore.likedPosts.count)")
                LabeledContent("Flash Cards Known",   value: "\(flashProgress.knownCardKeys.count)")
            }

            // ── Activity ───────────────────────────────────────────
            Section("Activity") {
                LabeledContent("Days Active",     value: "\(activityStore.activeDayCount)")
                LabeledContent("Articles Read",   value: "\(activityStore.totalArticlesRead)")
                LabeledContent("Blog Posts Read", value: "\(activityStore.totalBlogsRead)")
            }

            // ── Data ───────────────────────────────────────────────
            Section {
                Button(role: .destructive) { showClearConfirm = true } label: {
                    Label("Clear Reading Progress", systemImage: "trash")
                }
            } header: {
                Text("Data")
            } footer: {
                Text("Clears in-progress and completed article history. Does not delete downloaded files.")
            }

            // ── Sign Out ───────────────────────────────────────────
            Section {
                Button(role: .destructive) { showSignOutConfirm = true } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog("Clear Reading Progress?",
                            isPresented: $showClearConfirm,
                            titleVisibility: .visible) {
            Button("Clear Progress", role: .destructive) { progressStore.clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your in-progress and completed article history will be removed.")
        }
        .confirmationDialog("Sign Out?",
                            isPresented: $showSignOutConfirm,
                            titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { authStore.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will need to sign in again to use SDTool.")
        }
    }

    private func providerLabel(_ id: String) -> String {
        switch id {
        case "apple.com":  return "Signed in with Apple"
        case "google.com": return "Signed in with Google"
        default:           return "Signed in"
        }
    }

    private func providerIcon(_ id: String) -> String {
        switch id {
        case "apple.com":  return "applelogo"
        case "google.com": return "globe"
        default:           return "person.circle"
        }
    }
}

// MARK: - Article Settings

struct ArticleSettingsView: View {
    @AppStorage(AppSettings.Key.homeViewStyle) private var homeViewStyle = AppSettings.Default.homeViewStyle
    @ObservedObject private var progressStore = ReadingProgressStore.shared
    @StateObject   private var docStore       = DocStore()

    var body: some View {
        Form {
            Section("Display") {
                Picker("Home View Style", selection: $homeViewStyle) {
                    Label("Grid", systemImage: "square.grid.2x2").tag("grid")
                    Label("List", systemImage: "list.bullet").tag("list")
                }
                .pickerStyle(.segmented)
            }

            Section("Reading Progress") {
                LabeledContent("In Progress", value: "\(progressStore.inProgress.count) articles")
                LabeledContent("Completed",   value: "\(progressStore.completed.count) articles")
            }

            Section {
                LabeledContent("Downloaded", value: "\(docStore.docs.filter { $0.isDownloaded }.count) of \(docStore.docs.count)")
            } header: {
                Text("Storage")
            } footer: {
                Text("Downloaded articles are available offline.")
            }
        }
        .navigationTitle("Articles")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Blog Settings

struct BlogSettingsView: View {
    @AppStorage(AppSettings.Key.feedCacheHours) private var feedCacheHours = AppSettings.Default.feedCacheHours
    @ObservedObject private var blogStore  = BlogStore.shared
    @ObservedObject private var likedStore = LikedPostsStore.shared

    @State private var showClearLikedConfirm = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Feed Refresh Interval")
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
                Text("Feed Settings")
            } footer: {
                Text("How often to refresh blog feeds. Set to 0 to always fetch the latest.")
            }

            Section("Subscriptions") {
                LabeledContent("Subscribed Companies",
                               value: "\(blogStore.subscribed.count) of \(blogStore.companies.count)")
                LabeledContent("Liked Posts",
                               value: "\(likedStore.likedPosts.count)")
            }

            Section {
                Button(role: .destructive) {
                    showClearLikedConfirm = true
                } label: {
                    Label("Clear Liked Posts", systemImage: "heart.slash")
                }
                .disabled(likedStore.likedPosts.isEmpty)
            } header: {
                Text("Data")
            } footer: {
                Text("Removes all liked blog posts from your saved list.")
            }
        }
        .navigationTitle("Blogs")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "Clear Liked Posts?",
            isPresented: $showClearLikedConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) { likedStore.clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All liked blog posts will be removed.")
        }
    }
}

// MARK: - Flash Card Settings

struct FlashCardSettingsView: View {
    @ObservedObject private var flashStore    = FlashCardStore.shared
    @ObservedObject private var flashProgress = FlashCardProgress.shared

    @State private var showResetAllConfirm  = false
    @State private var deckToReset: FlashDeck? = nil
    @State private var showDeckResetConfirm = false

    var body: some View {
        Form {
            Section("Progress") {
                LabeledContent("Total Cards Known",
                               value: "\(flashProgress.knownCardKeys.count)")
                LabeledContent("Decks Available",
                               value: "\(flashStore.decks.count)")
            }

            Section {
                ForEach(flashStore.decks) { deck in
                    Button {
                        deckToReset          = deck
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
            } header: {
                Text("Reset by Deck")
            } footer: {
                Text("Marks all cards in a deck as unlearned so you can study them again.")
            }

            Section {
                Button(role: .destructive) {
                    showResetAllConfirm = true
                } label: {
                    Label("Reset All Progress", systemImage: "arrow.counterclockwise")
                }
                .disabled(flashProgress.knownCardKeys.isEmpty)
            } header: {
                Text("Reset All")
            } footer: {
                Text("Marks every card across all decks as unlearned.")
            }
        }
        .navigationTitle("Flash Cards")
        .navigationBarTitleDisplayMode(.large)
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

#Preview { SettingsView() }
