//
//  TermsOfServiceView.swift
//  SDTool
//
//  Full Terms of Service — presented from Settings, PrivacyConsentView, and LoginView.
//

import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss

    private let effectiveDate = "April 2, 2026"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Header card
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.indigo)
                    Text("Terms of Service")
                        .font(.title2.bold())
                    Text("Effective \(effectiveDate)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)

                PolicySection(
                    icon: "checkmark.circle.fill",
                    title: "Acceptance of Terms",
                    content: "By downloading, installing, or using SDTool (\"the App\") you agree to be bound by these Terms of Service. If you do not agree, do not use the App."
                )

                PolicySection(
                    icon: "books.vertical.fill",
                    title: "Description of Service",
                    content: "SDTool is a free educational application designed to help software engineers study system design concepts. Article content and flashcards are fetched from a public GitHub repository and provided for informational and educational purposes only. The App is not affiliated with any of the companies whose engineering blogs are aggregated."
                )

                PolicySection(
                    icon: "person.badge.key.fill",
                    title: "Account",
                    content: "You may use the App as a guest or by signing in with Google or Apple. You are responsible for maintaining the security of your account credentials. We reserve the right to terminate accounts that violate these Terms."
                )

                PolicySection(
                    icon: "hand.raised.fill",
                    title: "Acceptable Use",
                    content: "You agree not to:\n\u{2022} Reverse engineer, decompile, or disassemble the App\n\u{2022} Scrape, crawl, or systematically download content from the App or its backend\n\u{2022} Misuse or abuse the AI features in ways that violate Google's Gemini API terms\n\u{2022} Use the App for any unlawful purpose or in violation of any applicable laws\n\u{2022} Attempt to gain unauthorized access to any part of the App or its infrastructure"
                )

                PolicySection(
                    icon: "doc.badge.gearshape.fill",
                    title: "Intellectual Property",
                    content: "The App code and design are \u{00A9} 2026 Saurabh Sharma. Article content is sourced from a public GitHub repository under its respective license. Third-party blog content aggregated in the App belongs to the respective publishing companies and is used for informational purposes only. All trademarks belong to their respective owners."
                )

                PolicySection(
                    icon: "sparkles",
                    title: "AI Features",
                    content: "AI functionality is powered by Google Gemini via Firebase AI Logic. AI-generated responses are provided for informational purposes only and may contain errors or inaccuracies. Daily usage quotas apply and are shared across all App users. We make no guarantees about the availability or accuracy of AI-generated content."
                )

                PolicySection(
                    icon: "exclamationmark.triangle.fill",
                    title: "Disclaimers",
                    content: "The App and all content within it are provided \"as is\" without warranty of any kind, express or implied. We do not warrant that the content is accurate, complete, current, or error-free. Educational content should not be relied upon as professional advice. System design concepts evolve and content may become outdated."
                )

                PolicySection(
                    icon: "shield.slash.fill",
                    title: "Limitation of Liability",
                    content: "To the maximum extent permitted by applicable law, Saurabh Sharma shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of, or inability to use, the App or its content. Our total liability shall not exceed the amount you paid for the App (zero, as the App is free)."
                )

                PolicySection(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Changes to Terms",
                    content: "We reserve the right to modify these Terms at any time. The effective date at the top of this page will be updated when changes are made. Continued use of the App after changes are posted constitutes your acceptance of the revised Terms."
                )

                PolicySection(
                    icon: "envelope.fill",
                    title: "Contact",
                    content: "Questions about these Terms? Please open an issue on our GitHub repository. We aim to respond promptly."
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
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}

#Preview {
    NavigationStack { TermsOfServiceView() }
}
