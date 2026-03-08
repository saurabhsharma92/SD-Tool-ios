//
//  LoginView.swift
//  SDTool
//

import SwiftUI
import GoogleSignInSwift

struct LoginView: View {
    @ObservedObject private var authStore = AuthStore.shared

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.14),
                    Color(red: 0.10, green: 0.08, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint:   .bottomTrailing
            )
            .ignoresSafeArea()

            // Decorative circles
            Circle()
                .fill(Color.indigo.opacity(0.15))
                .frame(width: 320, height: 320)
                .offset(x: -100, y: -260)
                .blur(radius: 40)
            Circle()
                .fill(Color.purple.opacity(0.12))
                .frame(width: 260, height: 260)
                .offset(x: 130, y: 300)
                .blur(radius: 50)

            VStack(spacing: 0) {
                Spacer()

                // App icon + title
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(LinearGradient(
                                colors: [.indigo, Color(red: 0.5, green: 0.2, blue: 0.9)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 88, height: 88)
                            .shadow(color: .indigo.opacity(0.5), radius: 20, y: 8)
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 6) {
                        Text("SDTool")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Your system design study companion")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()

                // Sign-in buttons
                VStack(spacing: 14) {
                    if authStore.isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                            .frame(height: 50)
                    } else {
                        #if DEBUG
                        Button {
                            Task { await authStore.signInAnonymously() }
                        } label: {
                            Text("⚡ Skip Sign-In (Debug)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.yellow.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.yellow.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                                )
                        }
                        #endif

                        // Sign in with Google
                        Button {
                            Task { await authStore.signInWithGoogle() }
                        } label: {
                            HStack(spacing: 10) {
                                Image("google_logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                Text("Continue with Google")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }

                    if let error = authStore.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 28)

                // Footer
                Text("By continuing you agree to our Terms of Service")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)

                Spacer().frame(height: 40)
            }
        }
    }
}

#Preview { LoginView() }
