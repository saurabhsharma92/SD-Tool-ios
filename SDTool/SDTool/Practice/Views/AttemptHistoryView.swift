//
//  AttemptHistoryView.swift
//  SDTool
//
//  Shows past submission attempts for a specific problem level.
//

import SwiftUI
import FirebaseAuth

struct AttemptHistoryView: View {
    let problem: SDProblem
    let level: SDLevel

    @State private var attempts: [SDAttempt] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading attempts…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if attempts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("No attempts yet")
                            .font(.headline)
                        Text("Submit your design to see history here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(attempts, id: \.id) { attempt in
                        AttemptRowView(attempt: attempt)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Level \(level.levelNumber) History")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await load() }
    }

    private func load() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        do {
            attempts = try await SDAttemptService.shared.fetchAttempts(
                userId:      uid,
                problemId:   problem.id,
                levelNumber: level.levelNumber
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Row

private struct AttemptRowView: View {
    let attempt: SDAttempt

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: pass/fail badge + score + date
            HStack {
                Label(
                    attempt.passed ? "Passed" : "Failed",
                    systemImage: attempt.passed ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(attempt.passed ? .green : .orange)

                Spacer()

                Text("\(Int(attempt.score * 100))%")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Components used
            if !attempt.components.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Components")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    FlowTagsView(tags: attempt.components, color: .accentColor)
                }
            }

            // Connections
            if !attempt.connections.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connections")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    FlowTagsView(tags: attempt.connections, color: .indigo)
                }
            }

            // Feedback
            if !attempt.feedback.isEmpty {
                Text(attempt.feedback)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }

    private var formattedDate: String {
        let date = Date(timeIntervalSince1970: attempt.attemptedAt)
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Tag chips (wrapping)

private struct FlowTagsView: View {
    let tags: [String]
    let color: Color

    var body: some View {
        // Simple horizontal scroll for tags
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(color.opacity(0.1))
                        .foregroundStyle(color)
                        .clipShape(Capsule())
                }
            }
        }
    }
}
