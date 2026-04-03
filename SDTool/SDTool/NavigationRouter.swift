//
//  NavigationRouter.swift
//  SDTool
//

import SwiftUI
import Combine

// Shared navigation state — lets HomeView trigger deep navigation
// in other tabs by setting the active tab + destination.
@MainActor
final class NavigationRouter: ObservableObject {
    static let shared = NavigationRouter()

    // Which tab is selected (matches ContentView tab indices)
    @Published var selectedTab: Int = 0

    // Increments every time the Home tab is tapped (including re-taps).
    // HomeV2 observes this to reset its strip to Favorites.
    @Published var homeTabTrigger: Int = 0

    // Article tab deep link — set to a Doc to push DocReaderView
    @Published var articleDestination: Doc? = nil

    // Blog tab deep link — set to a company to push CompanyBlogView
    @Published var blogDestination: BlogCompany? = nil

    private init() {}

    func openArticle(_ doc: Doc) {
        articleDestination = doc
        selectedTab = 1          // Article tab
    }

    func openBlogPost(_ url: URL, company: BlogCompany?) {
        if let company {
            blogDestination = company
            selectedTab = 2      // Blogs tab
        } else {
            // No company info — just open in Safari
            UIApplication.shared.open(url)
        }
    }

    func openBlogURL(_ url: URL) {
        UIApplication.shared.open(url)
    }
}
