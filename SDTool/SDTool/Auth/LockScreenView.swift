//
//  LockScreenView.swift
//  SDTool
//

import SwiftUI

struct LockScreenView: View {
    @ObservedObject private var biometric = BiometricService.shared

    var body: some View {
        ZStack {
            // Background — matches LoginView palette
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.14),
                    Color(red: 0.10, green: 0.08, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint:   .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.indigo.opacity(0.15))
                .frame(width: 300, height: 300)
                .offset(x: -80, y: -220)
                .blur(radius: 40)

            VStack(spacing: 32) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 100, height: 100)
                    Image(systemName: biometric.biometricIcon)
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 10) {
                    Text("SDTool is Locked")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Use \(biometric.biometricLabel) to continue")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                VStack(spacing: 14) {
                    if biometric.isAuthenticating {
                        ProgressView().tint(.white)
                    } else {
                        Button {
                            Task { await biometric.authenticate() }
                        } label: {
                            Label(
                                "Unlock with \(biometric.biometricLabel)",
                                systemImage: biometric.biometricIcon
                            )
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.indigo)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    if let error = biometric.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            Task { await biometric.authenticate() }
        }
    }
}

#Preview { LockScreenView() }
