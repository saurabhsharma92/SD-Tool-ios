//
//  AIQuotaBadge.swift
//  SDTool
//
//  Compact quota indicator shown in all AI sheets and chat.
//  Shows remaining requests for today + a colour-coded arc.
//

import SwiftUI

struct AIQuotaBadge: View {
    @AppStorage(AppSettings.Key.geminiModel) private var modelRaw = AppSettings.Default.geminiModel
    @ObservedObject private var quota = AIQuotaStore.shared

    /// If true shows full breakdown popover; false = compact inline pill
    var expanded: Bool = false

    private var model: AppSettings.GeminiModel {
        AppSettings.GeminiModel(rawValue: modelRaw) ?? .flashLite
    }

    private var remaining: Int    { quota.remaining(for: model) }
    private var fraction: Double  { quota.fraction(for: model) }
    private var used: Int         { quota.usedToday }
    private var isExhausted: Bool { quota.isExhausted }

    private var statusColor: Color {
        if isExhausted { return .red }
        switch fraction {
        case ..<0.5:  return .green
        case ..<0.75: return .yellow
        case ..<0.9:  return .orange
        default:      return .red
        }
    }

    /// Label shown for "Est. Left" — clarifies server-confirmed exhaustion
    private var remainingLabel: String {
        isExhausted ? "Confirmed 0" : "Est. Left*"
    }

    /// Footer disclaimer
    private var disclaimer: String {
        isExhausted
            ? "⚠️ Server confirmed quota exhausted. Resets midnight PT."
            : "* Tracks your device only. Quota is shared across all users."
    }

    var body: some View {
        if expanded {
            expandedBadge
        } else {
            compactBadge
        }
    }

    // MARK: - Compact pill (used in sheet toolbars)

    private var compactBadge: some View {
        HStack(spacing: 5) {
            // Mini arc
            ZStack {
                Circle()
                    .stroke(statusColor.opacity(0.2), lineWidth: 2.5)
                    .frame(width: 16, height: 16)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 16, height: 16)
                    .animation(.easeInOut(duration: 0.4), value: fraction)
            }

            Text("\(remaining)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(statusColor)

            Text("used today")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.thinMaterial, in: Capsule())
        .overlay(Capsule().stroke(statusColor.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Expanded card (used in Settings)

    private var expandedBadge: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header row
            HStack {
                Label("Your AI Usage — Today", systemImage: "brain")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(model.shortLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 8)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [statusColor.opacity(0.7), statusColor],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * fraction), height: 8)
                        .animation(.easeInOut(duration: 0.5), value: fraction)
                }
            }
            .frame(height: 8)

            // Numbers row
            HStack {
                quotaStat(value: "\(used)",              label: "Used")
                Divider().frame(height: 28)
                quotaStat(value: "\(remaining)",         label: remainingLabel, color: statusColor)
                Divider().frame(height: 28)
                quotaStat(value: "\(model.dailyLimit)",  label: "Daily Limit")
            }

            // Breakdown
            if !quota.breakdown.isEmpty {
                Divider()
                HStack(spacing: 8) {
                    ForEach(AICallType.allCases, id: \.self) { type in
                        let count = quota.breakdown[type] ?? 0
                        if count > 0 {
                            breakdownChip(type: type, count: count)
                        }
                    }
                }
            }

            // Reset note
            Text("Resets at midnight Pacific Time")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(disclaimer)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private func quotaStat(value: String, label: String, color: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func breakdownChip(type: AICallType, count: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.system(size: 9))
            Text("\(type.label) ×\(count)")
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
        .foregroundStyle(.secondary)
    }
}
