//
//  SDToolApp.swift
//  SDTool
//
//  Created by Saurabh Sharma on 2/28/26.
//
import SwiftUI

@main
struct SDToolApp: App {

    @AppStorage(AppSettings.Key.colorScheme) private var colorScheme = AppSettings.Default.colorScheme

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(Color("AccentColor"))
                .preferredColorScheme(AppSettings.preferredColorScheme(for: colorScheme))
        }
    }
}
