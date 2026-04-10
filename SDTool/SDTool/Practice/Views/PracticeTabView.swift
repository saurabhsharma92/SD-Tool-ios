//
//  PracticeTabView.swift
//  SDTool
//
//  Root view for the Practice tab.
//  Loads problems from Firestore and shows them in a list sorted by difficulty
//  (hidden from users) with per-problem level progress indicators.
//

import SwiftUI
import Combine

struct PracticeTabView: View {
    @ObservedObject private var problemStore  = SDProblemStore.shared
    @ObservedObject private var progressStore = SDProgressStore.shared

    var body: some View {
        NavigationStack {
            Group {
                if problemStore.isLoading {
                    loadingState
                } else if problemStore.problems.isEmpty {
                    emptyState
                } else {
                    problemList
                }
            }
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: SDProblem.self) { problem in
                ProblemDetailView(problem: problem)
            }
        }
        .task {
            await problemStore.load()
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading problems…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "pencil.and.diagram")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)

            Text("No Problems Available")
                .font(.headline)

            if let err = problemStore.errorMessage {
                Text(err)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            } else {
                Text("Problems are loaded from Firestore.\nMake sure the database is seeded.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button("Retry") { Task { await problemStore.load() } }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var problemList: some View {
        List(problemStore.problems) { problem in
            ZStack {
                ProblemRowView(problem: problem, progressStore: progressStore)
                NavigationLink(value: problem) { EmptyView() }.opacity(0)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
    }
}
