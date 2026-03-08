//
//  SDToolApp.swift
//  SDTool
//

import SwiftUI
import FirebaseCore
import FirebaseAppCheck

@main
struct SDToolApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppSettings.Key.colorScheme) private var colorScheme = AppSettings.Default.colorScheme
    @AppStorage(AppSettings.Key.appFont)     private var appFont     = AppSettings.Default.appFont

    @ObservedObject private var authStore: AuthStore
    @ObservedObject private var biometric: BiometricService

    init() {
        // App Check — debug provider for simulator/dev, DeviceCheck for release
        #if DEBUG
        let providerFactory = AppCheckDebugProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        #endif

        FirebaseApp.configure()
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
                } else if needsBiometric {
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

    // Biometric gate — skipped for debug bypass
    private var needsBiometric: Bool {
        #if DEBUG
        if authStore.debugBypass { return false }
        #endif
        return !biometric.isUnlocked
    }

    private var splashView: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.14).ignoresSafeArea()
            ProgressView().tint(.white).scaleEffect(1.3)
        }
    }
}
