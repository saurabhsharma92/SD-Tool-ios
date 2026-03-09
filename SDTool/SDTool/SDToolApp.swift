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
    @AppStorage(AppSettings.Key.fontSize)    private var fontSize    = AppSettings.Default.fontSize

    @ObservedObject private var authStore: AuthStore
    @ObservedObject private var biometric: BiometricService

    // Controls whether the funny splash plays after sign-in
    @State private var showSplash: Bool = false

    init() {
        // App Check provider:
        // - DEBUG builds (simulator + direct Xcode runs): debug token
        // - RELEASE builds (TestFlight + App Store): App Attest
        // AppCheckAppAttestProviderFactory is Firebase's built-in factory — no custom class needed.
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(AppCheckAppAttestProviderFactory())
        #endif

        FirebaseApp.configure()
        authStore = AuthStore.shared
        biometric = BiometricService.shared
    }

    private var fontDesign: Font.Design {
        AppSettings.AppFont(rawValue: appFont)?.design ?? .default
    }

    private var fontSizeCategory: ContentSizeCategory {
        switch fontSize {
        case ..<0.85: return .extraSmall
        case ..<0.95: return .small
        case ..<1.05: return .medium
        case ..<1.15: return .large
        case ..<1.25: return .extraLarge
        case ..<1.35: return .extraExtraLarge
        default:      return .extraExtraExtraLarge
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authStore.isLoading {
                    // Firebase checking persisted session — plain spinner
                    firebaseLoadingView

                } else if !authStore.isSignedIn {
                    // Not signed in — show login
                    LoginView()
                        .transition(.opacity)

                } else if showSplash {
                    // Funny animation plays once after each sign-in
                    SplashView {
                        showSplash = false
                    }
                    .transition(.opacity)

                } else if needsBiometric {
                    LockScreenView()
                        .transition(.opacity)

                } else {
                    ContentView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: authStore.isSignedIn)
            .animation(.easeInOut(duration: 0.35), value: showSplash)
            .animation(.easeInOut(duration: 0.35), value: biometric.isUnlocked)
            .preferredColorScheme(AppSettings.preferredColorScheme(for: colorScheme))
            .environment(\.font, .system(size: 17 * fontSize, design: fontDesign))
            .environment(\.sizeCategory, fontSizeCategory)
            .onChange(of: authStore.isSignedIn) { _, signedIn in
                // Trigger the funny splash the moment the user signs in
                if signedIn { showSplash = true }
            }
        }
        .onChange(of: scenePhase) { _, phase in
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

    private var needsBiometric: Bool {
        #if DEBUG
        if authStore.debugBypass { return false }
        #endif
        return !biometric.isUnlocked
    }

    private var firebaseLoadingView: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.14).ignoresSafeArea()
            ProgressView().tint(.white).scaleEffect(1.3)
        }
    }
}
