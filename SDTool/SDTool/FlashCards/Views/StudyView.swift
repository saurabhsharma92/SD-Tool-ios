//
//  StudyView.swift
//  SDTool
//

import SwiftUI

struct StudyView: View {
    let deck: FlashDeck

    @ObservedObject private var progress = FlashCardProgress.shared
    @Environment(\.dismiss) private var dismiss

    // Session state — built once on appear, not reactive to progress changes mid-session
    @State private var sessionCards: [FlashCard] = []
    @State private var currentIndex: Int         = 0
    @State private var isFlipped:    Bool         = false
    @State private var isComplete:   Bool         = false
    @State private var rotation:     Double       = 0

    private var current: FlashCard? {
        guard currentIndex < sessionCards.count else { return nil }
        return sessionCards[currentIndex]
    }

    private var remaining: Int { sessionCards.count - currentIndex }

    var body: some View {
        Group {
            if isComplete || sessionCards.isEmpty {
                completionView
            } else {
                studyContent
            }
        }
        .navigationTitle(deck.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isComplete)
        .onAppear { buildSession() }
    }

    // MARK: - Study content

    private var studyContent: some View {
        VStack(spacing: 0) {

            // ── Progress bar ───────────────────────────────────────
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemFill))
                        .frame(height: 4)
                    Rectangle()
                        .fill(Color("AccentColor"))
                        .frame(
                            width: geo.size.width * progressFraction,
                            height: 4
                        )
                        .animation(.easeInOut(duration: 0.3), value: currentIndex)
                }
            }
            .frame(height: 4)

            // ── Counter ────────────────────────────────────────────
            Text("\(remaining) remaining · \(deck.knownCount(progress: progress)) known")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 16)

            Spacer()

            // ── Flip card ──────────────────────────────────────────
            if let card = current {
                flipCard(card: card)
                    .padding(.horizontal, 24)
                    .gesture(
                        DragGesture(minimumDistance: 40)
                            .onEnded { value in
                                // Works from both question and answer side.
                                // Never shows the answer when swiping from question.
                                if value.translation.width > 0 {
                                    markKnown()
                                } else {
                                    reviewLater()
                                }
                            }
                    )

                Text("Swipe right  ✓ Know it  ·  Swipe left  ↩ Review later")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 16)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // ── Action buttons (shown after flip) ──────────────────
            if isFlipped {
                actionButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Spacer().frame(height: 120)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Flip card

    private func flipCard(card: FlashCard) -> some View {
        ZStack {
            // Front face
            cardFace(text: card.front, isFront: true)
                .opacity(rotation < 90 ? 1 : 0)

            // Back face
            cardFace(text: card.back, isFront: false)
                .opacity(rotation >= 90 ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
        .onTapGesture { flipCard() }
        .id(currentIndex)   // forces view reset on card change
    }

    private func cardFace(text: String, isFront: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)

            VStack(spacing: 12) {
                Text(isFront ? "QUESTION" : "ANSWER")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(isFront ? Color("AccentColor") : .green)
                    .tracking(1.5)

                Text(text)
                    .font(.title3)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 240)
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        HStack(spacing: 14) {
            // Review Later
            Button {
                reviewLater()
            } label: {
                Label("Review Later", systemImage: "arrow.uturn.right")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            // Know It
            Button {
                markKnown()
            } label: {
                Label("Know It", systemImage: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Completion view

    private var completionView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("All Done! 🎉")
                .font(.largeTitle.bold())

            Text("You've gone through all cards in \(deck.displayName).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Text("\(deck.knownCount(progress: progress)) of \(deck.totalCards) cards known")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(spacing: 12) {
                // Reset and study again
                Button {
                    progress.reset(deck: deck)
                    buildSession()
                    isComplete = false
                } label: {
                    Text("Study Again")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color("AccentColor"))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    dismiss()
                } label: {
                    Text("Back to Decks")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Actions

    private func flipCard() {
        withAnimation(.easeInOut(duration: 0.4)) {
            rotation = isFlipped ? 0 : 180
            isFlipped.toggle()
        }
    }

    private func markKnown() {
        guard let card = current else { return }
        progress.markKnown(card)
        advance()
    }

    private func reviewLater() {
        guard currentIndex < sessionCards.count else { return }
        let card = sessionCards.remove(at: currentIndex)
        sessionCards.append(card)
        resetFlip()
        // Don't advance index — next card slides in
        if currentIndex >= sessionCards.count { currentIndex = 0 }
    }

    private func advance() {
        if currentIndex + 1 >= sessionCards.count {
            isComplete = true
        } else {
            currentIndex += 1
            resetFlip()
        }
    }

    private func resetFlip() {
        withAnimation(.easeInOut(duration: 0.2)) {
            rotation  = 0
            isFlipped = false
        }
    }

    private func buildSession() {
        // Only show unknown cards, shuffled
        sessionCards = deck.unknownCards(progress: progress).shuffled()
        currentIndex = 0
        isComplete   = sessionCards.isEmpty
        resetFlip()
    }

    private var progressFraction: Double {
        guard !sessionCards.isEmpty else { return 1 }
        return Double(currentIndex) / Double(sessionCards.count)
    }
}
