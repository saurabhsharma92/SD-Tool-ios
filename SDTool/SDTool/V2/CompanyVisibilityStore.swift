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

// MARK: - Company group model

struct CompanyGroup: Identifiable, Codable, Hashable {
    var id:           String
    var name:         String
    var companyNames: [String]

    init(name: String, companyNames: [String] = []) {
        self.id           = UUID().uuidString
        self.name         = name
        self.companyNames = companyNames
    }
}

// MARK: - Company visibility + pinning store

final class CompanyVisibilityStore: ObservableObject {
    static let shared = CompanyVisibilityStore()

    @Published private(set) var disabledCompanies: Set<String>    = []
    @Published private(set) var pinnedCompanies:   [String]       = []
    @Published private(set) var pinnedGroupIDs:    [String]       = []
    @Published private(set) var customFeeds:       [CustomRSSFeed] = []
    @Published private(set) var companyGroups:     [CompanyGroup]  = []

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

    // MARK: - Group pinning

    func isGroupPinned(_ groupID: String) -> Bool {
        pinnedGroupIDs.contains(groupID)
    }

    func toggleGroupPin(_ groupID: String) {
        if let idx = pinnedGroupIDs.firstIndex(of: groupID) {
            pinnedGroupIDs.remove(at: idx)
        } else {
            pinnedGroupIDs.append(groupID)
        }
        savePinnedGroups()
    }

    /// Returns groups sorted: pinned first (in pin order), then rest alphabetically
    func sortedGroups() -> [CompanyGroup] {
        let pinned = pinnedGroupIDs.compactMap { id in companyGroups.first { $0.id == id } }
        let rest   = companyGroups.filter { !pinnedGroupIDs.contains($0.id) }
                                  .sorted { $0.name < $1.name }
        return pinned + rest
    }

    // MARK: - Company groups

    func addGroup(_ group: CompanyGroup) {
        companyGroups.append(group)
        saveGroups()
    }

    func removeGroup(id: String) {
        companyGroups.removeAll { $0.id == id }
        saveGroups()
    }

    func addToGroup(companyName: String, groupID: String) {
        guard let i = companyGroups.firstIndex(where: { $0.id == groupID }) else { return }
        if !companyGroups[i].companyNames.contains(companyName) {
            companyGroups[i].companyNames.append(companyName)
            saveGroups()
        }
    }

    func removeFromGroup(companyName: String, groupID: String) {
        guard let i = companyGroups.firstIndex(where: { $0.id == groupID }) else { return }
        companyGroups[i].companyNames.removeAll { $0 == companyName }
        if companyGroups[i].companyNames.isEmpty { removeGroup(id: groupID) }
        else { saveGroups() }
    }

    func groupContaining(_ companyName: String) -> CompanyGroup? {
        companyGroups.first { $0.companyNames.contains(companyName) }
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
        if let data = ud.data(forKey: AppSettings.V2Key.companyGroups),
           let arr  = try? JSONDecoder().decode([CompanyGroup].self, from: data) {
            companyGroups = arr
        }
        if let data = ud.data(forKey: AppSettings.V2Key.pinnedGroupIDs),
           let arr  = try? JSONDecoder().decode([String].self, from: data) {
            pinnedGroupIDs = arr
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

    private func saveGroups() {
        if let data = try? JSONEncoder().encode(companyGroups) {
            ud.set(data, forKey: AppSettings.V2Key.companyGroups)
        }
    }

    private func savePinnedGroups() {
        if let data = try? JSONEncoder().encode(pinnedGroupIDs) {
            ud.set(data, forKey: AppSettings.V2Key.pinnedGroupIDs)
        }
    }
}
