//
//  ContentView.swift
//  SDTool
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            DocListView()
                .tabItem {
                    Label("Article", systemImage: "text.book.closed.fill")
                }

            BlogsView()
                .tabItem {
                    Label("Blogs", systemImage: "newspaper.fill")
                }

            FlashCardsHomeView()
                .tabItem {
                    Label("Flash Cards", systemImage: "rectangle.stack.fill")
                }

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
