//
//  RSSFeedSheet.swift
//  SDTool
//
//  Sheet for adding a custom RSS/Atom feed as a new company tab.
//

import SwiftUI
import Combine

struct RSSFeedSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var visibility = CompanyVisibilityStore.shared

    @State private var displayName: String = ""
    @State private var feedURL:     String = ""
    @State private var isValidating: Bool  = false
    @State private var validationError: String? = nil
    @State private var didValidate: Bool   = false

    private var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !feedURL.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display name", text: $displayName)
                        .autocorrectionDisabled()
                    TextField("Feed URL (RSS or Atom)", text: $feedURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("Feed details")
                } footer: {
                    Text("Paste an RSS or Atom feed URL. The feed will appear as its own tab on the Home screen.")
                        .font(.caption)
                }

                if let err = validationError {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        validate()
                    } label: {
                        if isValidating {
                            HStack {
                                ProgressView().scaleEffect(0.8)
                                Text("Checking feed…")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Validate feed")
                        }
                    }
                    .disabled(!canSave || isValidating)
                } footer: {
                    Text("Validation checks the URL is reachable and returns a valid feed.")
                        .font(.caption)
                }
            }
            .navigationTitle("Add custom feed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        save()
                    }
                    .disabled(!canSave || isValidating)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Actions

    private func validate() {
        guard let url = URL(string: feedURL.trimmingCharacters(in: .whitespaces)) else {
            validationError = "Not a valid URL"
            return
        }
        isValidating    = true
        validationError = nil

        Task {
            do {
                let (_, response) = try await URLSession.shared.data(from: url)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                await MainActor.run {
                    isValidating = false
                    if (200..<300).contains(status) {
                        didValidate     = true
                        validationError = nil
                    } else {
                        validationError = "Feed returned HTTP \(status)"
                    }
                }
            } catch {
                await MainActor.run {
                    isValidating    = false
                    validationError = error.localizedDescription
                }
            }
        }
    }

    private func save() {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        let url  = feedURL.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !url.isEmpty else { return }
        let feed = CustomRSSFeed(displayName: name, feedURL: url)
        visibility.addFeed(feed)
        dismiss()
    }
}

#Preview {
    RSSFeedSheet()
}
