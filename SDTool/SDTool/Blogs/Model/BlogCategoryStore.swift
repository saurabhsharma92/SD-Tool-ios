//
//  BlogCategoryStore.swift
//  SDTool
//

import Foundation
import Combine
import SwiftUI

class BlogCategoryStore: ObservableObject {
    static let shared = BlogCategoryStore()

    @Published var categoryOrder: [String] = []

    private let saveKey = "blogCategoryOrder"

    init() { load() }

    // MARK: - Public

    func move(from source: IndexSet, to destination: Int) {
        categoryOrder.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func reset() {
        categoryOrder = BlogCatalog.defaultCategoryOrder
        save()
    }

    // MARK: - Persistence

    private func save() {
        UserDefaults.standard.set(categoryOrder, forKey: saveKey)
    }

    private func load() {
        if let saved = UserDefaults.standard.stringArray(forKey: saveKey),
           !saved.isEmpty {
            categoryOrder = saved
        } else {
            categoryOrder = BlogCatalog.defaultCategoryOrder
        }
    }
}
