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

    // Font design (serif/mono/rounded) applied via environment
    private var fontDesign: Font.Design {
        AppSettings.AppFont(rawValue: appFont)?.design ?? .default
    }

    /// Maps fontSize scale to ContentSizeCategory so all relative fonts scale together
    private var fontSizeCategory: ContentSizeCategory {
        switch fontSize {
        case ..<0.85: return .extraSmall
        case ..<0.95: return .small
        case ..<1.05: return .medium          // default
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
            .environment(\.font, .system(size: 17 * fontSize, design: fontDesign))
            // Also propagate size to all relative fonts via environment
            .environment(\.sizeCategory, fontSizeCategory)
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
