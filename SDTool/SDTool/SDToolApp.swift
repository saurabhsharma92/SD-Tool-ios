//
//  SDToolApp.swift
//  SDTool
//

import SwiftUI
import FirebaseCore

@main
struct SDToolApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppSettings.Key.colorScheme) private var colorScheme = AppSettings.Default.colorScheme
    @AppStorage(AppSettings.Key.appFont)      private var appFont      = AppSettings.Default.appFont

    // Both stores initialized AFTER FirebaseApp.configure() in init()
    @ObservedObject private var authStore: AuthStore
    @ObservedObject private var biometric: BiometricService

    init() {
        FirebaseApp.configure()
        // Now safe to access Firebase services
        authStore = AuthStore.shared
        biometric = BiometricService.shared
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authStore.isLoading {
                    splashView
                } else if !authStore.isSignedIn {
                    LoginView()
                } else if !biometric.isUnlocked {
                    LockScreenView()
                } else {
                    ContentView()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authStore.isSignedIn)
            .animation(.easeInOut(duration: 0.3), value: biometric.isUnlocked)
            .preferredColorScheme(AppSettings.preferredColorScheme(for: colorScheme))
            .environment(\.font, AppSettings.AppFont(rawValue: appFont)?.font ?? .body)
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background:
                biometric.lock()
            case .active:
                if authStore.isSignedIn && !biometric.isUnlocked {
                    Task { await biometric.authenticate() }
                }
            default:
                break
            }
        }
    }

    private var splashView: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.14).ignoresSafeArea()
            ProgressView().tint(.white).scaleEffect(1.3)
        }
    }
}
