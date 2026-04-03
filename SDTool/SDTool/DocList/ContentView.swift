//
//  ContentView.swift
//  SDTool
//

import SwiftUI

struct ContentView: View {
    @StateObject private var router = NavigationRouter.shared

    var body: some View {
        if FeatureFlags.useNewUI {
            newTabView
        } else {
            legacyTabView
        }
    }

    // MARK: - New v2 layout (3 tabs)

    // Custom binding: forwards selection normally, but also fires homeTabTrigger
    // whenever tab 0 is tapped — even if it is already selected.
    private var homeAwareSelection: Binding<Int> {
        Binding(
            get: { router.selectedTab },
            set: { newTab in
                router.selectedTab = newTab
                if newTab == 0 { router.homeTabTrigger += 1 }
            }
        )
    }

    private var newTabView: some View {
        TabView(selection: homeAwareSelection) {
            HomeV2()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            FlashCardsHomeView()
                .tabItem { Label("Flash Cards", systemImage: "rectangle.stack.fill") }
                .tag(3)

            SettingsV2()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(4)
        }
    }

    // MARK: - Legacy 5-tab layout (unchanged)

    private var legacyTabView: some View {
        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            DocListView()
                .tabItem { Label("Article", systemImage: "text.book.closed.fill") }
                .tag(1)

            BlogsView()
                .tabItem { Label("Blogs", systemImage: "newspaper.fill") }
                .tag(2)

            FlashCardsHomeView()
                .tabItem { Label("Flash Cards", systemImage: "rectangle.stack.fill") }
                .tag(3)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(4)
        }
    }
}

#Preview { ContentView() }
