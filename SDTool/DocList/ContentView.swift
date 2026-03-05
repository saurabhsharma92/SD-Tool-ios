//
//  ContentView.swift
//  SDTool
//
//  Created by Saurabh Sharma on 3/4/26.
//
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            // Tab 1: Home — document library
            DocListView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            // Tab 2: Blogs — engineering blog feeds (Phase 6)
            BlogsView()
                .tabItem {
                    Label("Blogs", systemImage: "newspaper.fill")
                }

            // Tab 3: Settings — preferences
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
