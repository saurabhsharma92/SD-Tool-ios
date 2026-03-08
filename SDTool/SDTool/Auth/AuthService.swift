//
//  AuthService.swift
//  SDTool
//

import Foundation
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthService: NSObject {
    static let shared = AuthService()

    // MARK: - Google Sign-In

    func signInWithGoogle(presenting viewController: UIViewController) async throws -> FirebaseAuth.User {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.configurationMissing
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingToken
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken:     idToken,
            accessToken:     result.user.accessToken.tokenString
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        return authResult.user
    }

    // MARK: - Apple Sign-In

    // Nonce stored between request and completion
    private var currentNonce: String?

    func signInWithApple() async throws -> FirebaseAuth.User {
        let nonce = randomNonce()
        currentNonce = nonce

        return try await withCheckedThrowingContinuation { continuation in
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes    = [.fullName, .email]
            request.nonce              = sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            AppleSignInDelegate.shared.continuation = continuation
            AppleSignInDelegate.shared.nonce        = nonce
            controller.delegate                     = AppleSignInDelegate.shared
            controller.presentationContextProvider  = AppleSignInDelegate.shared
            controller.performRequests()
        }
    }

    // MARK: - Sign Out

    func signOut() throws {
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
    }

    // MARK: - Nonce helpers

    private func randomNonce(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let data   = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case configurationMissing
    case missingToken
    case cancelled

    var errorDescription: String? {
        switch self {
        case .configurationMissing: return "Firebase configuration missing."
        case .missingToken:         return "Could not retrieve sign-in token."
        case .cancelled:            return "Sign-in was cancelled."
        }
    }
}

// MARK: - Apple Sign-In Delegate (handles ASAuthorization callbacks)

final class AppleSignInDelegate: NSObject,
                                  ASAuthorizationControllerDelegate,
                                  ASAuthorizationControllerPresentationContextProviding {

    static let shared = AppleSignInDelegate()

    var continuation: CheckedContinuation<FirebaseAuth.User, Error>?
    var nonce:        String?

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let nonce,
            let tokenData = appleIDCredential.identityToken,
            let tokenString = String(data: tokenData, encoding: .utf8)
        else {
            continuation?.resume(throwing: AuthError.missingToken)
            continuation = nil
            return
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken:            tokenString,
            rawNonce:               nonce,
            fullName:               appleIDCredential.fullName
        )

        Task { @MainActor in
            do {
                let result = try await Auth.auth().signIn(with: credential)
                self.continuation?.resume(returning: result.user)
            } catch {
                self.continuation?.resume(throwing: error)
            }
            self.continuation = nil
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
            continuation?.resume(throwing: AuthError.cancelled)
        } else {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}
