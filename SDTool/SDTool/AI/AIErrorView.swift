//
//  AIErrorView.swift
//  SDTool
//
//  Shared error card used by ArticleAISheet, BlogAISheet, and ArticleChatView.
//  Shows a distinct icon, colour, title, plain-English explanation,
//  and a context-appropriate action button.
//

import SwiftUI

struct AIErrorView: View {
    let error: AIError
    var onRetry: (() -> Void)?          // nil hides the retry button
    var onOpenSettings: (() -> Void)?   // shown for model/config errors

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 32)

            // Icon badge
            ZStack {
                Circle()
                    .fill(error.color.opacity(0.1))
                    .frame(width: 72, height: 72)
                Circle()
                    .stroke(error.color.opacity(0.2), lineWidth: 1.5)
                    .frame(width: 72, height: 72)
                Image(systemName: error.systemImage)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(error.color)
            }
            .padding(.bottom, 20)

            // Title
            Text(error.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.bottom, 8)

            // Explanation
            Text(error.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

            // Action buttons
            VStack(spacing: 10) {
                if error.isRetryable, let retry = onRetry {
                    Button(action: retry) {
                        Label("Try Again", systemImage: "arrow.clockwise")
                            .frame(maxWidth: 220)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(error.color)
                }

                // Model config errors — shortcut to Settings
                if case .modelNotFound = error {
                    settingsButton
                }
                if case .permissionDenied = error {
                    settingsButton
                }

                // Quota error — show quota badge inline
                if case .quotaExceeded = error {
                    quotaCallout
                }
                if case .rateLimited(let s) = error {
                    rateLimitCallout(seconds: s)
                }
            }

            Spacer(minLength: 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sub-views

    private var settingsButton: some View {
        Button(action: { onOpenSettings?() }) {
            Label("Open Settings", systemImage: "gear")
                .frame(maxWidth: 220)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
    }

    private var quotaCallout: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge.checkmark")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Resets at midnight Pacific Time")
                    .font(.caption.weight(.medium))
                Text("Or switch to Gemini 2.0 Flash in Settings for a higher limit")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.orange.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 24)
    }

    private func rateLimitCallout(seconds: Int?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "clock")
                .foregroundStyle(.yellow)
            if let s = seconds {
                Text("Suggested wait: \(s)s before retrying")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Wait a moment before retrying")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.yellow.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 24)
    }
}

// MARK: - Inline chat error bubble
// Used inside ArticleChatView message list instead of the full-screen card

struct AIErrorBubble: View {
    let error: AIError
    var onRetry: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: error.systemImage)
                .font(.system(size: 14))
                .foregroundStyle(error.color)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(error.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(error.color)
                Text(error.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if error.isRetryable, let retry = onRetry {
                    Button(action: retry) {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(error.color)
                    .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .background(error.color.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(error.color.opacity(0.15), lineWidth: 1))
        .padding(.horizontal, 16)
    }
}
