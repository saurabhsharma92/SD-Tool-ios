//
//  SDToolApp.swift
//  SDTool
//

import SwiftUI

@main
struct SDToolApp: App {

    @AppStorage(AppSettings.Key.colorScheme) private var colorScheme = AppSettings.Default.colorScheme

    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .tint(Color("AccentColor"))
                    .preferredColorScheme(AppSettings.preferredColorScheme(for: colorScheme))

                if showSplash {
                    SplashView {
                        withAnimation(.easeOut(duration: 0.35)) {
                            showSplash = false
                        }
                    }
                    .preferredColorScheme(AppSettings.preferredColorScheme(for: colorScheme))
                    .zIndex(1)
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.35), value: showSplash)
        }
    }
}
