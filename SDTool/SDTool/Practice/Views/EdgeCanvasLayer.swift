//
//  EdgeCanvasLayer.swift
//  SDTool
//
//  Draws directed edges between nodes. Supports:
//  - Bidirectional pairs: rendered with perpendicular offset so both arrows are visible
//  - Dotted style: dashed stroke
//  - Curved style: quadratic bezier arc
//
//  EdgeInteractionLayer (separate view) overlays invisible long-press targets
//  at each edge midpoint — only active in connect mode.
//

import SwiftUI

// MARK: - Arrow drawing

struct EdgeCanvasLayer: View {
    let nodes: [CanvasNode]
    let edges: [CanvasEdge]

    var body: some View {
        Canvas { ctx, _ in
            for edge in edges {
                guard
                    let from = nodes.first(where: { $0.id == edge.fromNodeId }),
                    let to   = nodes.first(where: { $0.id == edge.toNodeId })
                else { continue }

                let hasReverse = edges.contains {
                    $0.fromNodeId == edge.toNodeId && $0.toNodeId == edge.fromNodeId
                }
                drawArrow(
                    ctx:        ctx,
                    from:       from.position,
                    to:         to.position,
                    sideOffset: hasReverse ? 10 : 0,
                    isDotted:   edge.isDotted,
                    isCurved:   edge.isCurved
                )
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Draw single arrow

    private func drawArrow(
        ctx: GraphicsContext,
        from: CGPoint,
        to: CGPoint,
        sideOffset: CGFloat,
        isDotted: Bool,
        isCurved: Bool
    ) {
        guard from != to else { return }

        let dx   = to.x - from.x
        let dy   = to.y - from.y
        let dist = sqrt(dx * dx + dy * dy)
        let pad: CGFloat = 42

        guard dist > pad * 2 else { return }

        let ux = dx / dist
        let uy = dy / dist
        let px = -uy   // perpendicular x
        let py =  ux   // perpendicular y

        let adjFrom = CGPoint(x: from.x + ux * pad + px * sideOffset,
                              y: from.y + uy * pad + py * sideOffset)
        let adjTo   = CGPoint(x: to.x   - ux * pad + px * sideOffset,
                              y: to.y   - uy * pad + py * sideOffset)

        var path = Path()

        if isCurved {
            // Quadratic bezier: control point offset perpendicular at midpoint
            let curveBulge: CGFloat = min(dist * 0.25, 60)
            let control = CGPoint(
                x: (adjFrom.x + adjTo.x) / 2 + px * curveBulge,
                y: (adjFrom.y + adjTo.y) / 2 + py * curveBulge
            )
            path.move(to: adjFrom)
            path.addQuadCurve(to: adjTo, control: control)

            // Arrowhead tangent at curve end
            let t: CGFloat = 0.95
            let tx = 2 * (1 - t) * (control.x - adjFrom.x) + 2 * t * (adjTo.x - control.x)
            let ty = 2 * (1 - t) * (control.y - adjFrom.y) + 2 * t * (adjTo.y - control.y)
            drawArrowhead(into: &path, at: adjTo, angle: atan2(ty, tx))
        } else {
            path.move(to: adjFrom)
            path.addLine(to: adjTo)
            drawArrowhead(into: &path, at: adjTo,
                          angle: atan2(adjTo.y - adjFrom.y, adjTo.x - adjFrom.x))
        }

        let stroke = StrokeStyle(
            lineWidth: 2,
            lineCap:   .round,
            dash:      isDotted ? [6, 5] : []
        )
        ctx.stroke(path, with: .color(.primary.opacity(0.65)), style: stroke)
    }

    private func drawArrowhead(into path: inout Path, at tip: CGPoint, angle: Double) {
        let len: CGFloat  = 12
        let spread        = Double.pi / 6
        path.move(to: tip)
        path.addLine(to: CGPoint(x: tip.x - len * cos(angle - spread),
                                 y: tip.y - len * sin(angle - spread)))
        path.move(to: tip)
        path.addLine(to: CGPoint(x: tip.x - len * cos(angle + spread),
                                 y: tip.y - len * sin(angle + spread)))
    }
}

// MARK: - Long-press interaction layer (connect mode only)

struct EdgeInteractionLayer: View {
    let nodes:          [CanvasNode]
    let edges:          [CanvasEdge]
    let onDelete:       (UUID) -> Void
    let onReverse:      (UUID) -> Void
    let onToggleDotted: (UUID) -> Void
    let onToggleCurved: (UUID) -> Void

    @State private var selectedEdgeId: UUID? = nil
    @State private var showActions:    Bool  = false

    var body: some View {
        ForEach(edges) { edge in
            if let from = nodes.first(where: { $0.id == edge.fromNodeId }),
               let to   = nodes.first(where: { $0.id == edge.toNodeId }) {
                let mid = edgeMidpoint(from: from.position, to: to.position, edge: edge)
                Color.clear
                    .frame(width: 56, height: 56)
                    .contentShape(Rectangle())
                    .position(mid)
                    .onLongPressGesture(minimumDuration: 0.4) {
                        selectedEdgeId = edge.id
                        showActions    = true
                    }
            }
        }
        .confirmationDialog("Connection", isPresented: $showActions, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let id = selectedEdgeId { onDelete(id) }
            }
            Button("Reverse Direction") {
                if let id = selectedEdgeId { onReverse(id) }
            }
            Button(selectedEdge?.isDotted == true ? "Make Solid" : "Make Dotted") {
                if let id = selectedEdgeId { onToggleDotted(id) }
            }
            Button(selectedEdge?.isCurved == true ? "Make Straight" : "Make Curved") {
                if let id = selectedEdgeId { onToggleCurved(id) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var selectedEdge: CanvasEdge? {
        guard let id = selectedEdgeId else { return nil }
        return edges.first(where: { $0.id == id })
    }

    private func edgeMidpoint(from: CGPoint, to: CGPoint, edge: CanvasEdge) -> CGPoint {
        let hasReverse = edges.contains {
            $0.fromNodeId == edge.toNodeId && $0.toNodeId == edge.fromNodeId
        }
        let offset: CGFloat = hasReverse ? 10 : 0
        let dx   = to.x - from.x
        let dy   = to.y - from.y
        let dist = sqrt(dx * dx + dy * dy)
        let px   = dist > 0 ? -dy / dist * offset : 0
        let py   = dist > 0 ?  dx / dist * offset : 0
        return CGPoint(x: (from.x + to.x) / 2 + px,
                       y: (from.y + to.y) / 2 + py)
    }
}
