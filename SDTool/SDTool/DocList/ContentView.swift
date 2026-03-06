//
//  ContentView.swift
//  SDTool
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {

            // Tab 1: Home — dashboard
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            // Tab 2: Article — doc library (renamed from Home)
            DocListView()
                .tabItem {
                    Label("Article", systemImage: "text.book.closed.fill")
                }

            // Tab 3: Blogs — engineering blog feeds
            BlogsView()
                .tabItem {
                    Label("Blogs", systemImage: "newspaper.fill")
                }

            // Tab 4: Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
}
