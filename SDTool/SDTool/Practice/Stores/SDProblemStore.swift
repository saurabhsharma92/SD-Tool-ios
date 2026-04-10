//
//  SDProblemStore.swift
//  SDTool
//
//  Singleton store that loads and holds the full problem list from Firestore.
//

import Foundation
import Combine

@MainActor
final class SDProblemStore: ObservableObject {
    static let shared = SDProblemStore()

    @Published private(set) var problems:     [SDProblem] = []
    @Published private(set) var isLoading:    Bool        = false
    @Published private(set) var errorMessage: String?     = nil

    private init() {}

    func load() async {
        guard !isLoading else { return }
        isLoading    = true
        errorMessage = nil

        do {
            problems = try await SDProblemService.shared.fetchProblems()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
