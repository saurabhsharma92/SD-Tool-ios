//
//  AuthStore.swift
//  SDTool
//

import SwiftUI
import FirebaseAuth
import Combine


final class AuthStore: ObservableObject {
    static let shared: AuthStore = AuthStore()

    @Published private(set) var user:      FirebaseAuth.User? = nil
    @Published private(set) var isLoading: Bool               = true   // true while checking session
    @Published var            errorMessage: String?           = nil

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    private init() {
        // Auth.auth() is safe here because FirebaseApp.configure()
        // is guaranteed to run before AuthStore.shared is first accessed
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.user      = user
                self?.isLoading = false
            }
        }

        // Safety timeout — if listener doesn't fire in 4s (e.g. no network), unblock UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.isLoading else { return }
            self.isLoading = false
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Computed

    var isSignedIn: Bool {
        #if DEBUG
        return user != nil || debugBypass
        #else
        return user != nil
        #endif
    }

    #if DEBUG
    @Published var debugBypass: Bool = false
    #endif

    var displayName: String {
        #if DEBUG
        if debugBypass { return "Debug User" }
        if user?.isAnonymous == true { return "Debug User" }
        #endif
        return user?.displayName ?? user?.email?.components(separatedBy: "@").first ?? "User"
    }

    var email: String {
        user?.email ?? ""
    }

    var photoURL: URL? {
        user?.photoURL
    }

    var isAnonymous: Bool {
        user?.isAnonymous ?? false
    }

    var initials: String {
        let name = displayName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    // MARK: - Sign In

    @MainActor func signInWithGoogle() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        isLoading    = true
        errorMessage = nil
        do {
            let u = try await AuthService.shared.signInWithGoogle(presenting: rootVC)
            user      = u
            isLoading = false
        } catch AuthError.cancelled {
            isLoading = false   // silent — user dismissed
        } catch {
            errorMessage = error.localizedDescription
            isLoading    = false
        }
    }

    @MainActor func signInWithApple() async {
        isLoading    = true
        errorMessage = nil
        do {
            let u = try await AuthService.shared.signInWithApple()
            user      = u
            isLoading = false
        } catch AuthError.cancelled {
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading    = false
        }
    }

    // MARK: - Anonymous (debug only)

    #if DEBUG
    @MainActor func signInAnonymously() async {
        isLoading    = true
        errorMessage = nil
        do {
            let result = try await Auth.auth().signInAnonymously()
            user      = result.user
            isLoading = false
        } catch {
            // Firebase anonymous failed (e.g. not enabled) — use local bypass
            debugBypass = true
            isLoading   = false
        }
    }
    #endif

    // MARK: - Sign Out

    @MainActor func signOut() {
        do {
            try AuthService.shared.signOut()
            user = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
