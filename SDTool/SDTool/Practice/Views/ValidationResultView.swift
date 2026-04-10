//
//  ValidationResultView.swift
//  SDTool
//
//  Sheet shown after a user submits their canvas design.
//  Displays the pass/fail badge, algorithmic score, AI feedback (or fallback hint),
//  and action buttons for advancing to the next level.
//

import SwiftUI

struct ValidationResultView: View {
    let result: ValidationResult
    let problem: SDProblem
    let level: SDLevel
    let onDismiss: () -> Void
    let onLevelComplete: () -> Void

    @State private var levelMarked = false

    private var isLastLevel: Bool { level.levelNumber == problem.levelCount }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    scoreBadge
                    fallbackBanners
                    if !result.passed { gapCard }
                    feedbackCard
                    actionButtons
                }
                .padding(20)
            }
            .navigationTitle(result.passed ? "Level Passed!" : "Keep Trying")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                }
            }
        }
    }

    // MARK: - Score badge

    private var scoreBadge: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((result.passed ? Color.green : Color.orange).opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: result.passed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(result.passed ? .green : .orange)
            }

            Text(result.passed ? "Great work!" : "Not quite there yet")
                .font(.title3.weight(.semibold))

            Text("Match score: \(Int(result.score * 100))%")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !result.passed {
                Text("You need ≥ 80% to pass this level.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Fallback banners

    @ViewBuilder
    private var fallbackBanners: some View {
        if result.isGuestFallback {
            banner(
                icon: "person.fill.questionmark",
                text: "Sign in to unlock AI-powered feedback.",
                color: .indigo
            )
        } else if result.isQuotaFallback {
            banner(
                icon: "clock.fill",
                text: "Daily AI quota reached — showing hint feedback instead.",
                color: .orange
            )
        }
    }

    private func banner(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text).font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Gap card (shown only on failure)

    private var gapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What's Missing", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            if !result.missingComponents.isEmpty {
                gapSection(
                    title: "Missing blocks",
                    items: result.missingComponents,
                    color: .red
                )
            }

            if !result.missingConnections.isEmpty {
                gapSection(
                    title: "Missing connections",
                    items: result.missingConnections,
                    color: .orange
                )
            }

            if !result.extraComponents.isEmpty {
                gapSection(
                    title: "Unnecessary blocks (hurts score)",
                    items: result.extraComponents,
                    color: .purple
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.orange.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func gapSection(title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(items, id: \.self) { item in
                        Text(item)
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(color.opacity(0.12))
                            .foregroundStyle(color)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Feedback card

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Feedback", systemImage: "text.bubble.fill")
                .font(.headline)

            Text(result.aiFeedback ?? result.fallbackHint)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if result.passed {
                if isLastLevel {
                    primaryButton(
                        title: "Problem Complete! 🎉",
                        icon: "star.fill",
                        color: .green
                    ) {
                        markAndDismiss()
                    }
                } else {
                    primaryButton(
                        title: "Continue to Level \(level.levelNumber + 1)",
                        icon: "arrow.right.circle.fill",
                        color: .accentColor
                    ) {
                        markAndDismiss()
                    }
                }
            }

            Button {
                onDismiss()
            } label: {
                Text(result.passed ? "Review my design" : "Try again")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func primaryButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(color)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func markAndDismiss() {
        if !levelMarked {
            onLevelComplete()
            levelMarked = true
        }
        onDismiss()
    }
}
