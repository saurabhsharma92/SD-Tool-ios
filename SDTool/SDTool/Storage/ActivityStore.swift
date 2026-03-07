//
//  ActivityStore.swift
//  SDTool
//

import Foundation
import Combine

// MARK: - Models

struct DailyActivity: Identifiable, Codable {
    var id:           String   // "yyyy-MM-dd"
    var articleReads: Set<String>  // filenames read that day
    var blogReads:    Set<String>  // "companyName::postTitle" read that day

    var date: Date {
        Self.calendar.date(from: Self.formatter.date(from: id)
            .map { Self.calendar.dateComponents([.year, .month, .day], from: $0) }
            ?? DateComponents()) ?? Date()
    }

    var totalReads: Int { articleReads.count + blogReads.count }
    var hasActivity: Bool { !articleReads.isEmpty || !blogReads.isEmpty }

    static let calendar  = Calendar.current
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

// MARK: - Store

class ActivityStore: ObservableObject {
    static let shared = ActivityStore()

    @Published private(set) var days: [DailyActivity] = []

    private let saveKey = "dailyActivityLog"

    init() { load() }

    // MARK: - Record reads

    func recordArticleRead(filename: String) {
        let key = todayKey()
        ensureToday(key)
        guard let i = days.firstIndex(where: { $0.id == key }) else { return }
        days[i].articleReads.insert(filename)
        save()
    }

    func recordBlogRead(companyName: String, postTitle: String) {
        let key = todayKey()
        ensureToday(key)
        guard let i = days.firstIndex(where: { $0.id == key }) else { return }
        days[i].blogReads.insert("\(companyName)::\(postTitle)")
        save()
    }

    // MARK: - Query

    /// Returns the last `count` days as DailyActivity, oldest first.
    /// Missing days (no activity) are filled with empty entries.
    func recentDays(_ count: Int = 30) -> [DailyActivity] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<count).reversed().map { offset -> DailyActivity in
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            let key  = DailyActivity.formatter.string(from: date)
            return days.first(where: { $0.id == key })
                ?? DailyActivity(id: key, articleReads: [], blogReads: [])
        }
    }

    func activity(for date: Date) -> DailyActivity? {
        let key = DailyActivity.formatter.string(from: date)
        return days.first(where: { $0.id == key })
    }

    // MARK: - Helpers

    private func todayKey() -> String {
        DailyActivity.formatter.string(from: Date())
    }

    private func ensureToday(_ key: String) {
        if !days.contains(where: { $0.id == key }) {
            days.append(DailyActivity(id: key, articleReads: [], blogReads: []))
        }
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(days) else { return }
        UserDefaults.standard.set(data, forKey: saveKey)
    }

    private func load() {
        if let data  = UserDefaults.standard.data(forKey: saveKey),
           let saved = try? JSONDecoder().decode([DailyActivity].self, from: data) {
            days = saved
        }
    }
}
