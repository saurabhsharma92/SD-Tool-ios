//
//  PrivacyPolicyView.swift
//  SDTool
//
//  Full Privacy Policy — presented from Settings and PrivacyConsentView.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    private let effectiveDate = "April 2, 2026"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Header card
                VStack(spacing: 8) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.indigo)
                    Text("Privacy Policy")
                        .font(.title2.bold())
                    Text("Effective \(effectiveDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)

                PolicySection(
                    icon: "info.circle.fill",
                    title: "About This Policy",
                    content: "This Privacy Policy describes how SDTool (\"the App\", \"we\", \"us\") collects, uses, and protects information when you use this application. By using SDTool you agree to the practices described here."
                )

                PolicySection(
                    icon: "person.fill",
                    title: "Information We Collect",
                    content: "When you sign in with Google or Apple, Firebase Authentication stores your email address and display name to identify your account. Guest users have no account data on our servers.\n\nOn-device only (never sent to our servers):\n\u{2022} Reading progress and bookmarks\n\u{2022} Favorite articles\n\u{2022} App settings and preferences\n\u{2022} AI usage counts (used to enforce daily quotas)\n\u{2022} Company blog visibility and pinning\n\nWe do not collect device identifiers, location data, or usage analytics beyond what Firebase Authentication requires for authentication."
                )

                PolicySection(
                    icon: "sparkles",
                    title: "AI Features",
                    content: "When you use Summary, Explain Simply, or Chat with Article, the text of the article you are reading is sent to Google's Gemini AI service to generate a response. No personal information (name, email, or account details) is included in these requests. AI features are entirely optional. Usage counts are tracked locally on your device only."
                )

                PolicySection(
                    icon: "building.2.fill",
                    title: "Third-Party Services",
                    content: "SDTool uses the following third-party services, each with their own privacy policies:\n\n\u{2022} Google Firebase (Authentication) \u{2014} manages sign-in\n\u{2022} Google Firebase AI Logic / Gemini \u{2014} powers AI features\n\u{2022} GitHub Raw Content API \u{2014} serves articles, blog index, and flashcard content; no personal data is sent\n\nWe do not use advertising networks, analytics SDKs, or any other data-collection services."
                )

                PolicySection(
                    icon: "icloud.fill",
                    title: "Data Storage & Retention",
                    content: "Account data (email, display name) is retained in Firebase Authentication for as long as your account exists. All other data \u{2014} reading progress, favorites, settings \u{2014} is stored locally on your device and deleted when you uninstall the app. If you delete your account via Settings \u{2192} Delete Account, your Firebase Authentication record is permanently removed."
                )

                PolicySection(
                    icon: "checkmark.shield.fill",
                    title: "Your Rights",
                    content: "You have the right to:\n\u{2022} Access the personal data we hold about you (your email / display name in Firebase)\n\u{2022} Correct inaccurate data by updating your Google or Apple account\n\u{2022} Delete your account and all associated data via Settings \u{2192} Delete Account\n\u{2022} Use the app as a guest without providing any personal information\n\nIf you are located in the European Economic Area (EEA) or California, you have additional rights under GDPR and CCPA respectively, including the right to data portability and the right to opt out of data sale (we do not sell data)."
                )

                PolicySection(
                    icon: "figure.child",
                    title: "Children's Privacy",
                    content: "SDTool is not directed at children under the age of 13. We do not knowingly collect personal information from children under 13. If you believe a child has provided us with personal information, please contact us so we can delete it."
                )

                PolicySection(
                    icon: "lock.shield.fill",
                    title: "Security",
                    content: "We rely on Firebase Authentication's industry-standard security for account data. Local data stored on your device is protected by iOS's built-in data protection mechanisms. No method of transmission over the internet is 100% secure; we cannot guarantee absolute security."
                )

                PolicySection(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Changes to This Policy",
                    content: "We may update this Privacy Policy from time to time. The effective date at the top of this page will reflect when it was last revised. Continued use of the app after changes constitutes acceptance of the updated policy."
                )

                PolicySection(
                    icon: "envelope.fill",
                    title: "Contact Us",
                    content: "If you have questions or concerns about this Privacy Policy, please open an issue on our GitHub repository. We will respond as soon as possible."
                )

                Text("\u{00A9} 2026 Saurabh Sharma. All rights reserved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}

// MARK: - Shared section component

struct PolicySection: View {
    let icon:    String
    let title:   String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.indigo)
                    .frame(width: 28, height: 28)
                    .background(Color.indigo.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack { PrivacyPolicyView() }
}
