//
//  SDToolApp.swift
//  SDTool
//

import SwiftUI
import FirebaseCore
import FirebaseAppCheck

@main
struct SDToolApp: App {

    init() {
        // App Check — debug provider in simulator/DEBUG, App Attest in production
        #if DEBUG
        let providerFactory = AppCheckDebugProviderFactory()
        #else
        let providerFactory: any AppCheckProviderFactory = AppAttestProvider.isSupported
            ? AppAttestProviderFactory()
            : DeviceCheckProviderFactory()
        #endif
        AppCheck.setAppCheckProviderFactory(providerFactory)

        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
