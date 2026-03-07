//
//  BlogStore.swift
//  SDTool
//

import Foundation
import Combine

class BlogStore: ObservableObject {
    static let shared = BlogStore()

    @Published var companies:  [BlogCompany] = []
    @Published var isSyncing:  Bool    = false
    @Published var syncError:  String? = nil

    private let saveKey     = "blogCompanies"
    private let syncService = BlogSyncService.shared

    init() { load() }

    // MARK: - Computed

    var subscribed: [BlogCompany] {
        companies.filter { $0.isSubscribed }
    }

    var available: [BlogCompany] {
        companies.filter { !$0.isSubscribed }
    }

    var subscribedCategories: [String] {
        var seen = Set<String>()
        return subscribed.compactMap {
            seen.insert($0.category).inserted ? $0.category : nil
        }
    }

    var availableCategories: [String] {
        var seen = Set<String>()
        return available.compactMap {
            seen.insert($0.category).inserted ? $0.category : nil
        }
    }

    func subscribed(in category: String) -> [BlogCompany] {
        subscribed.filter { $0.category == category }
    }

    func available(in category: String) -> [BlogCompany] {
        available.filter { $0.category == category }
    }

    // MARK: - Subscribe / unsubscribe

    func subscribe(_ company: BlogCompany) {
        guard let i = companies.firstIndex(where: { $0.id == company.id }) else { return }
        companies[i].isSubscribed = true
        save()
    }

    func unsubscribe(_ company: BlogCompany) {
        guard let i = companies.firstIndex(where: { $0.id == company.id }) else { return }
        companies[i].isSubscribed = false
        save()
    }

    // MARK: - Sync

    func sync() {
        guard !isSyncing else { return }
        isSyncing = true
        syncError = nil

        Task {
            do {
                let fetched = try await syncService.fetchIndex()
                await MainActor.run {
                    mergeCompanies(fetched)
                    isSyncing = false
                    save()
                }
            } catch {
                await MainActor.run {
                    syncError = error.localizedDescription
                    isSyncing = false
                }
            }
        }
    }

    // MARK: - Merge

    private func mergeCompanies(_ fetched: [BlogCompany]) {
        var result: [BlogCompany] = []
        for var company in fetched {
            // Preserve subscription state for existing companies
            if let existing = companies.first(where: {
                $0.name == company.name
            }) {
                company.id           = existing.id
                company.isSubscribed = existing.isSubscribed
            }
            result.append(company)
        }
        // Keep locally subscribed companies not in remote index
        let fetchedNames = Set(fetched.map { $0.name })
        let orphans = companies.filter {
            $0.isSubscribed && !fetchedNames.contains($0.name)
        }
        result.append(contentsOf: orphans)
        companies = result
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(companies) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    private func load() {
        if let data   = UserDefaults.standard.data(forKey: saveKey),
           let saved  = try? JSONDecoder().decode([BlogCompany].self, from: data) {
            companies = saved
        }
    }
}
