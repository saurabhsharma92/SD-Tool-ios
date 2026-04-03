//
//  FeatureFlags.swift
//  SDTool
//
//  Toggle between old and new UI. Set useNewUI = true to enable the redesign.
//

import Foundation

enum FeatureFlags {
    /// Master switch for the v2 redesign.
    /// true  → new HomeV2 (tab strip: Favorites | Articles | Companies)
    /// false → original 5-tab layout unchanged
    static let useNewUI: Bool = true
}
