//
//  SolutionView.swift
//  SDTool
//
//  Shows the expected solution for a level.
//  Only revealed after 3 failed attempts.
//

import SwiftUI

struct SolutionView: View {
    let level: SDLevel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Context banner
                    HStack(spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                        Text("Study this solution, then close and try building it yourself.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yellow.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Required components
                    sectionCard(title: "Required Blocks", icon: "square.grid.2x2.fill", color: .blue) {
                        FlexWrapView(items: level.requiredComponents, color: .blue)
                    }

                    // Required connections
                    sectionCard(title: "Required Connections", icon: "arrow.right.circle.fill", color: .indigo) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(level.requiredConnections, id: \.self) { conn in
                                let parts = conn.components(separatedBy: "→")
                                HStack(spacing: 6) {
                                    if parts.count == 2 {
                                        Text(parts[0])
                                            .font(.caption.weight(.medium))
                                            .padding(.horizontal, 8).padding(.vertical, 3)
                                            .background(Color.indigo.opacity(0.12))
                                            .foregroundStyle(.indigo)
                                            .clipShape(Capsule())
                                        Image(systemName: "arrow.right")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(parts[1])
                                            .font(.caption.weight(.medium))
                                            .padding(.horizontal, 8).padding(.vertical, 3)
                                            .background(Color.indigo.opacity(0.12))
                                            .foregroundStyle(.indigo)
                                            .clipShape(Capsule())
                                    } else {
                                        Text(conn).font(.caption)
                                    }
                                }
                            }
                        }
                    }

                    // Why this works
                    sectionCard(title: "Why This Works", icon: "brain.fill", color: .teal) {
                        Text(level.aiContextHint)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Level \(level.levelNumber) Solution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Wrapping tag chips

private struct FlexWrapView: View {
    let items: [String]
    let color: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(color.opacity(0.12))
                        .foregroundStyle(color)
                        .clipShape(Capsule())
                }
            }
        }
    }
}
