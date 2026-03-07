//
//  DeckTileView.swift
//  SDTool
//

import SwiftUI

struct DeckTileView: View {
    let deck:     FlashDeck
    @ObservedObject var progress: FlashCardProgress

    private var total:   Int { deck.totalCards }
    private var known:   Int { deck.knownCount(progress: progress) }
    private var percent: Double {
        total > 0 ? Double(known) / Double(total) : 0
    }
    private var remaining: Int { total - known }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Top: emoji + progress ring ─────────────────────────
            HStack(alignment: .top) {
                Text(deck.emoji)
                    .font(.system(size: 32))

                Spacer()

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color(.systemFill), lineWidth: 4)
                        .frame(width: 40, height: 40)

                    Circle()
                        .trim(from: 0, to: percent)
                        .stroke(
                            percent >= 1 ? Color.green : Color("AccentColor"),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.5), value: percent)

                    Text("\(Int(percent * 100))%")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)

            // ── Deck name ──────────────────────────────────────────
            Text(deck.displayName)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .padding(.horizontal, 12)
                .padding(.top, 10)

            // ── Stats ──────────────────────────────────────────────
            HStack(spacing: 4) {
                Text("\(remaining) left")
                    .font(.caption2)
                    .foregroundStyle(remaining == 0 ? .green : .secondary)
                Text("·")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text("\(total) total")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 3)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            // "All done" green border when deck complete
            RoundedRectangle(cornerRadius: 16)
                .stroke(percent >= 1 ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
    }
}
