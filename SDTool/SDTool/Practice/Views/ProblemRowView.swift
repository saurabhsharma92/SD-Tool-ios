//
//  ProblemRowView.swift
//  SDTool
//
//  A single row in the problem list.
//  Shows title, tags, and level-completion progress.
//  Deliberately hides the `difficulty` field.
//

import SwiftUI

struct ProblemRowView: View {
    let problem: SDProblem
    @ObservedObject var progressStore: SDProgressStore

    private var completedCount: Int {
        progressStore.progress(for: problem.id)?.completedLevels.count ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(problem.title)
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(problem.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
            }

            Text("\(completedCount) / \(problem.levelCount) levels completed")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
    }
}
