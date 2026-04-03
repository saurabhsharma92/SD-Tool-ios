//
//  GuestRestrictionView.swift
//  SDTool
//
//  Shown to guest (anonymous) users when they try to access AI features.
//  Hard block with a clear message and sign-in CTA.
//

import SwiftUI

struct GuestRestrictionView: View {
    let feature: String
    @ObservedObject private var authStore = AuthStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.indigo.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "lock.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.indigo)
            }

            // Message
            VStack(spacing: 8) {
                Text("Feature limited")
                    .font(.title3.weight(.semibold))
                Text("\(feature) are not available in guest mode.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Info card
            VStack(alignment: .leading, spacing: 10) {
                InfoRow(icon: "sparkles",      text: "AI summaries and explanations")
                InfoRow(icon: "bubble.left",   text: "Chat with articles")
                InfoRow(icon: "heart.fill",    text: "Sync favorites across devices")
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 32)

            // CTA
            Button {
                dismiss()
                // Give the sheet time to dismiss before showing login
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    Task { try? await AuthStore.shared.signOut() }
                }
            } label: {
                Text("Sign in to unlock")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)

            Button {
                dismiss()
            } label: {
                Text("Not now")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

private struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.indigo)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    GuestRestrictionView(feature: "AI features")
}
