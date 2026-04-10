//
//  ProblemDetailView.swift
//  SDTool
//
//  Shows a problem's overview and a horizontal strip of level chips.
//  Each chip shows completion status and unlocks the canvas when tapped.
//

import SwiftUI
import Combine
import FirebaseAuth

struct ProblemDetailView: View {
    let problem: SDProblem

    @ObservedObject private var progressStore = SDProgressStore.shared
    @ObservedObject private var authStore     = AuthStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Overview card
                Text(problem.overview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                // Level strip
                VStack(alignment: .leading, spacing: 10) {
                    Text("Levels")
                        .font(.headline)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(problem.levels, id: \.levelNumber) { level in
                                LevelChip(
                                    level:       level,
                                    isCompleted: progressStore.isLevelCompleted(level.levelNumber, for: problem.id),
                                    isUnlocked:  progressStore.isLevelUnlocked(level.levelNumber, for: problem.id),
                                    problem:     problem
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 4)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(problem.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let uid = authStore.user?.uid {
                await progressStore.loadProgress(userId: uid, problemId: problem.id)
            }
        }
    }
}

// MARK: - Level chip

private struct LevelChip: View {
    let level: SDLevel
    let isCompleted: Bool
    let isUnlocked: Bool
    let problem: SDProblem

    var body: some View {
        NavigationLink {
            if isUnlocked {
                DesignCanvasView(problem: problem, level: level)
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: statusIcon)
                    .font(.system(size: 20))
                    .foregroundStyle(statusColor)

                Text("Level \(level.levelNumber)")
                    .font(.caption.weight(.medium))

                Text(level.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 82)
                    .lineLimit(2)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(borderColor, lineWidth: 1.5)
            )
            .opacity(isUnlocked ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
    }

    private var statusIcon: String {
        isCompleted ? "checkmark.circle.fill" : (isUnlocked ? "arrow.right.circle.fill" : "lock.fill")
    }

    private var statusColor: Color {
        isCompleted ? .green : (isUnlocked ? .accentColor : .secondary)
    }

    private var borderColor: Color {
        isCompleted ? .green.opacity(0.4) : (isUnlocked ? .accentColor.opacity(0.3) : .clear)
    }
}
