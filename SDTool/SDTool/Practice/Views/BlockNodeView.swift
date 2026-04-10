//
//  BlockNodeView.swift
//  SDTool
//
//  Renders a single building block on the canvas.
//  Drag gesture and .position() are applied by DesignCanvasView (parent),
//  which uses coordinateSpace(name: "canvas") for correct hit-test coordinates.
//

import SwiftUI
import Combine

struct BlockNodeView: View {
    let node: CanvasNode
    let isSelected: Bool
    let isConnectSource: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onSetScaling: (ScalingMode) -> Void

    private let size: CGFloat = 64

    private var blockHeight: CGFloat {
        switch node.type {
        case .apiGateway, .reverseProxy: return 90
        default: return size
        }
    }

    var body: some View {
        ZStack {
            switch node.scalingMode {
            case .horizontal: horizontalView
            case .vertical:   verticalView
            case .none:       singleBlock(highlighted: isSelected || isConnectSource)
            }
        }
        .onTapGesture { onTap() }
        .contextMenu { contextMenuItems }
        .animation(.easeInOut(duration: 0.15), value: node.scalingMode)
        .animation(.easeInOut(duration: 0.1),  value: isSelected)
    }

    // MARK: - Single block

    private func singleBlock(highlighted: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(blockColor.opacity(0.14))
                    .frame(width: size, height: blockHeight)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                highlighted ? blockColor : blockColor.opacity(0.35),
                                lineWidth: highlighted ? 2.5 : 1.5
                            )
                    )
                    .shadow(color: highlighted ? blockColor.opacity(0.25) : .clear, radius: 6)

                Image(systemName: node.type.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(blockColor)
            }

            Text(node.type.rawValue)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: size + 20)
    }

    // MARK: - Horizontal scaling: 3 explicit side-by-side blocks

    private var horizontalView: some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    let isMid = i == 1
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(blockColor.opacity(isMid ? 0.18 : 0.09))
                            .frame(width: 38, height: 38)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        isMid ? blockColor : blockColor.opacity(0.45),
                                        lineWidth: isMid ? 2 : 1
                                    )
                            )
                            .shadow(
                                color: (isSelected || isConnectSource) && isMid ? blockColor.opacity(0.3) : .clear,
                                radius: 5
                            )
                        Image(systemName: node.type.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(blockColor.opacity(isMid ? 1.0 : 0.5))
                    }
                }
            }
            Text(node.type.rawValue + " ×3")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(width: 150)
    }

    // MARK: - Vertical scaling: single block + ↑ badge

    private var verticalView: some View {
        ZStack(alignment: .topTrailing) {
            singleBlock(highlighted: isSelected || isConnectSource)
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green)
                .offset(x: 4, y: -4)
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private var contextMenuItems: some View {
        if node.scalingMode != .horizontal {
            Button {
                onSetScaling(.horizontal)
            } label: {
                Label("Horizontal Scaling", systemImage: "arrow.left.and.right")
            }
        }
        if node.scalingMode != .vertical {
            Button {
                onSetScaling(.vertical)
            } label: {
                Label("Vertical Scaling", systemImage: "arrow.up.and.down")
            }
        }
        if node.scalingMode != .none {
            Button {
                onSetScaling(.none)
            } label: {
                Label("Remove Scaling", systemImage: "minus.circle")
            }
        }
        Divider()
        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Colour

    private var blockColor: Color {
        switch node.type {
        case .input:        return .blue
        case .server:       return .orange
        case .rdbms:        return .green
        case .nosql:        return .teal
        case .cache:        return Color(hue: 0.13, saturation: 0.9, brightness: 0.9) // amber
        case .apiGateway:   return .purple
        case .cdn:          return .cyan
        case .reverseProxy: return .indigo
        case .readReplica:  return Color(hue: 0.55, saturation: 0.7, brightness: 0.85) // sky blue
        case .writeReplica: return Color(hue: 0.08, saturation: 0.8, brightness: 0.85) // coral
        case .fileStorage:  return Color(hue: 0.42, saturation: 0.6, brightness: 0.75) // forest green
        }
    }
}
