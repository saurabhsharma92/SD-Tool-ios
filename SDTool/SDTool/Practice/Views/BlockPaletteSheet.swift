//
//  BlockPaletteSheet.swift
//  SDTool
//
//  Bottom sheet grid letting users pick a building block to add to the canvas.
//

import SwiftUI
import Combine

struct BlockPaletteSheet: View {
    let onSelect: (BlockType) -> Void

    private let columns = Array(repeating: GridItem(.flexible()), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(BlockType.allCases) { type in
                        Button { onSelect(type) } label: {
                            paletteCell(for: type)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Add Block")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func paletteCell(for type: BlockType) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color(for: type).opacity(0.12))
                    .frame(width: 58, height: 58)
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color(for: type))
            }
            Text(type.rawValue)
                .font(.caption2)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 64)
        }
    }

    private func color(for type: BlockType) -> Color {
        switch type {
        case .input:        return .blue
        case .server:       return .orange
        case .rdbms:        return .green
        case .nosql:        return .teal
        case .cache:        return Color(hue: 0.13, saturation: 0.9, brightness: 0.9)
        case .apiGateway:   return .purple
        case .cdn:          return .cyan
        case .reverseProxy: return .indigo
        case .readReplica:  return Color(hue: 0.55, saturation: 0.7, brightness: 0.85)
        case .writeReplica: return Color(hue: 0.08, saturation: 0.8, brightness: 0.85)
        case .fileStorage:  return Color(hue: 0.42, saturation: 0.6, brightness: 0.75)
        }
    }
}
