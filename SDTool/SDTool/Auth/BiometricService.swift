//
//  BiometricService.swift
//  SDTool
//

import LocalAuthentication
import SwiftUI
import Combine

@MainActor
final class BiometricService: ObservableObject {
    static let shared = BiometricService()

    @Published private(set) var isUnlocked:     Bool = false
    @Published private(set) var isAuthenticating: Bool = false
    @Published var            errorMessage:     String? = nil

    // Whether the device supports biometrics
    var biometricType: LABiometryType {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return ctx.biometryType
    }

    var biometricLabel: String {
        switch biometricType {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        default:       return "Passcode"
        }
    }

    var biometricIcon: String {
        switch biometricType {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        default:       return "lock.fill"
        }
    }

    private init() {
        // If Face ID is disabled in settings, start unlocked
        let enabled = UserDefaults.standard.object(forKey: AppSettings.Key.faceIDEnabled) as? Bool ?? AppSettings.Default.faceIDEnabled
        if !enabled { isUnlocked = true }
    }

    // MARK: - Authenticate

    func authenticate() async {
        // Skip if Face ID disabled in settings
        let enabled = UserDefaults.standard.object(forKey: AppSettings.Key.faceIDEnabled) as? Bool ?? AppSettings.Default.faceIDEnabled
        guard enabled else { isUnlocked = true; return }
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Device has no biometrics and no passcode — just unlock
            isUnlocked  = true
            return
        }

        isAuthenticating = true
        errorMessage     = nil

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,   // Falls back to passcode if Face ID fails
                localizedReason: "Unlock SDTool"
            )
            isUnlocked       = success
            isAuthenticating = false
        } catch let laError as LAError {
            isAuthenticating = false
            switch laError.code {
            case .userCancel, .appCancel, .systemCancel:
                errorMessage = nil   // silent — user dismissed
            case .biometryNotEnrolled:
                // No Face ID enrolled — fall back silently, unlock via passcode
                isUnlocked = true
            default:
                errorMessage = laError.localizedDescription
            }
        } catch {
            isAuthenticating = false
            errorMessage     = error.localizedDescription
        }
    }

    // Called when app goes to background — re-lock
    func lock() {
        let enabled = UserDefaults.standard.object(forKey: AppSettings.Key.faceIDEnabled) as? Bool ?? AppSettings.Default.faceIDEnabled
        guard enabled else { return }
        isUnlocked = false
    }
}
