//
//  CompanyVisibilityStore.swift
//  SDTool
//
//  Defines CustomRSSFeed model and CompanyVisibilityStore.
//  Source of truth — AppSettingsV2.swift intentionally has no type definitions.
//

import Foundation
import Combine

// MARK: - Custom RSS Feed model

struct CustomRSSFeed: Identifiable, Codable, Hashable {
    var id:          String       // UUID string
    var displayName: String       // e.g. "Stripe Engineering"
    var feedURL:     String       // RSS/Atom URL
    var iconURL:     String?      // optional favicon URL
    var addedAt:     Date

    init(displayName: String, feedURL: String, iconURL: String? = nil) {
        self.id          = UUID().uuidString
        self.displayName = displayName
        self.feedURL     = feedURL
        self.iconURL     = iconURL
        self.addedAt     = Date()
    }
}

// MARK: - Company visibility + pinning store

final class CompanyVisibilityStore: ObservableObject {
    static let shared = CompanyVisibilityStore()

    @Published private(set) var disabledCompanies: Set<String> = []
    @Published private(set) var pinnedCompanies:   [String]    = []   // ordered
    @Published private(set) var customFeeds:       [CustomRSSFeed] = []

    private let ud = UserDefaults.standard

    private init() { load() }

    // MARK: - Company visibility

    func isEnabled(_ companyName: String) -> Bool {
        !disabledCompanies.contains(companyName)
    }

    func setEnabled(_ companyName: String, enabled: Bool) {
        if enabled {
            disabledCompanies.remove(companyName)
        } else {
            disabledCompanies.insert(companyName)
        }
        saveDisabled()
    }

    // MARK: - Pinning

    func isPinned(_ companyName: String) -> Bool {
        pinnedCompanies.contains(companyName)
    }

    func togglePin(_ companyName: String) {
        if let idx = pinnedCompanies.firstIndex(of: companyName) {
            pinnedCompanies.remove(at: idx)
        } else {
            pinnedCompanies.append(companyName)
        }
        savePinned()
    }

    /// Returns enabled companies sorted: pinned first (in pin order), then rest alphabetically
    func sorted(_ companies: [BlogCompany]) -> [BlogCompany] {
        let enabled = companies.filter { isEnabled($0.name) }
        let pinned  = pinnedCompanies.compactMap { name in enabled.first { $0.name == name } }
        let rest    = enabled.filter { !pinnedCompanies.contains($0.name) }
                             .sorted { $0.name < $1.name }
        return pinned + rest
    }

    // MARK: - Custom RSS feeds

    func addFeed(_ feed: CustomRSSFeed) {
        customFeeds.append(feed)
        saveFeeds()
    }

    func removeFeed(id: String) {
        customFeeds.removeAll { $0.id == id }
        saveFeeds()
    }

    // MARK: - Persistence

    private func load() {
        if let data = ud.data(forKey: AppSettings.V2Key.disabledCompanies),
           let arr  = try? JSONDecoder().decode([String].self, from: data) {
            disabledCompanies = Set(arr)
        }
        if let data = ud.data(forKey: AppSettings.V2Key.pinnedCompanies),
           let arr  = try? JSONDecoder().decode([String].self, from: data) {
            pinnedCompanies = arr
        }
        if let data = ud.data(forKey: AppSettings.V2Key.customRSSFeeds),
           let arr  = try? JSONDecoder().decode([CustomRSSFeed].self, from: data) {
            customFeeds = arr
        }
    }

    private func saveDisabled() {
        if let data = try? JSONEncoder().encode(Array(disabledCompanies)) {
            ud.set(data, forKey: AppSettings.V2Key.disabledCompanies)
        }
    }

    private func savePinned() {
        if let data = try? JSONEncoder().encode(pinnedCompanies) {
            ud.set(data, forKey: AppSettings.V2Key.pinnedCompanies)
        }
    }

    private func saveFeeds() {
        if let data = try? JSONEncoder().encode(customFeeds) {
            ud.set(data, forKey: AppSettings.V2Key.customRSSFeeds)
        }
    }
}
