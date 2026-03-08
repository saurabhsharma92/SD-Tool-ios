//
//  ContentView.swift
//  SDTool
//

import SwiftUI

struct ContentView: View {
    @StateObject private var router = NavigationRouter.shared
    @AppStorage(AppSettings.Key.colorScheme) private var colorScheme = AppSettings.Default.colorScheme

    var body: some View {
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
        .preferredColorScheme(AppSettings.preferredColorScheme(for: colorScheme))
    }
}

#Preview { ContentView() }
