//
//  PrivacyConsentView.swift
//  SDTool
//
//  Shown once on first launch before the login screen.
//  User must accept to continue. Declining exits the app.
//

import SwiftUI

struct PrivacyConsentView: View {
    var onAccept: () -> Void

    @State private var showPrivacy = false
    @State private var showTerms   = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.indigo)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "books.vertical.fill")
                            .foregroundStyle(.white)
                            .font(.system(size: 20))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Before you continue")
                        .font(.title3.weight(.semibold))
                    Text("SDTool · Privacy & Data")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
            .padding(.bottom, 28)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    PrivacySection(
                        icon: "person.fill",
                        title: "What we collect",
                        bodyText: "When you sign in, we store your name and email through Firebase Authentication. We also collect anonymous usage data (which features you use, not what you read) to improve the app. We do not sell your data."
                    )

                    PrivacySection(
                        icon: "sparkles",
                        title: "AI features",
                        bodyText: "When you use Summary, Explain Simply, or Chat with Article — the article text is sent to Google's Gemini AI servers to generate a response. No personal information is included in these requests. AI features are optional and can be disabled in Settings."
                    )

                    PrivacySection(
                        icon: "icloud.fill",
                        title: "Data storage",
                        bodyText: "Your reading progress, favorites, and settings are stored locally on your device using UserDefaults. They are not synced to a server unless you sign in."
                    )

                    PrivacySection(
                        icon: "trash.fill",
                        title: "Your rights",
                        bodyText: "You can delete your account and all associated data at any time from Settings → Delete Account. Guest users have no server-side data to delete."
                    )

                    // Links row
                    HStack(spacing: 0) {
                        Button("Privacy Policy") { showPrivacy = true }
                            .font(.footnote)
                            .foregroundStyle(.indigo)
                        Text("  ·  ")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Terms of Service") { showTerms = true }
                            .font(.footnote)
                            .foregroundStyle(.indigo)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }

            Divider()

            // Buttons
            VStack(spacing: 10) {
                Button {
                    UserDefaults.standard.set(true, forKey: AppSettings.V2Key.hasAcceptedPrivacy)
                    onAccept()
                } label: {
                    Text("Accept and continue")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.indigo)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    exit(0)
                } label: {
                    Text("Decline")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showPrivacy) {
            NavigationStack { PrivacyPolicyView() }
        }
        .sheet(isPresented: $showTerms) {
            NavigationStack { TermsOfServiceView() }
        }
    }
}

// MARK: - Section component

private struct PrivacySection: View {
    let icon:     String
    let title:    String
    let bodyText: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.indigo)
                .frame(width: 28, height: 28)
                .background(Color.indigo.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(bodyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    PrivacyConsentView(onAccept: {})
}
