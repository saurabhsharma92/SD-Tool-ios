//
//  ScrollPositionStore.swift
//  SDTool
//
//  Created by Saurabh Sharma on 2/28/26.
//

import Foundation

/// Persists and restores scroll position per document (UserDefaults keyed by doc id).
enum ScrollPositionStore {
    private static let prefix = "scrollPosition_"

    static func key(for docId: String) -> String {
        prefix + docId
    }

    static func save(offset: Double, for docId: String) {
        UserDefaults.standard.set(offset, forKey: key(for: docId))
    }

    static func load(for docId: String) -> Double? {
        let value = UserDefaults.standard.double(forKey: key(for: docId))
        return value > 0 ? value : nil
    }
}
