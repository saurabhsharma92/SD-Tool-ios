//
//  SDCanvasStore.swift
//  SDTool
//
//  Per-canvas ObservableObject. One instance per DesignCanvasView (created with @StateObject).
//  Not a singleton — each problem level gets a fresh canvas.
//

import Foundation
import CoreGraphics
import Combine

@MainActor
final class SDCanvasStore: ObservableObject {

    @Published var nodes:          [CanvasNode] = []
    @Published var edges:          [CanvasEdge] = []
    @Published var selectedNodeId: UUID?        = nil
    @Published var connectMode:    Bool         = false
    @Published var connectSourceId: UUID?       = nil   // first node tapped in connect mode

    // MARK: - Node operations

    func addNode(type: BlockType, at position: CGPoint) {
        nodes.append(CanvasNode(type: type, position: position))
    }

    func moveNode(id: UUID, to position: CGPoint) {
        guard let i = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[i].position = position
    }

    func deleteNode(id: UUID) {
        nodes.removeAll           { $0.id == id }
        edges.removeAll           { $0.fromNodeId == id || $0.toNodeId == id }
        if selectedNodeId  == id  { selectedNodeId  = nil }
        if connectSourceId == id  { connectSourceId = nil }
    }

    func setScaling(id: UUID, mode: ScalingMode) {
        guard let i = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[i].scalingMode = mode
    }

    // MARK: - Edge operations

    func deleteEdge(id: UUID) {
        edges.removeAll { $0.id == id }
    }

    func reverseEdge(id: UUID) {
        guard let i = edges.firstIndex(where: { $0.id == id }) else { return }
        let e = edges[i]
        // Only reverse if the reverse direction doesn't already exist
        guard !edges.contains(where: { $0.fromNodeId == e.toNodeId && $0.toNodeId == e.fromNodeId }) else { return }
        edges[i] = CanvasEdge(from: e.toNodeId, to: e.fromNodeId, isDotted: e.isDotted, isCurved: e.isCurved)
    }

    func toggleDotted(id: UUID) {
        guard let i = edges.firstIndex(where: { $0.id == id }) else { return }
        edges[i].isDotted.toggle()
    }

    func toggleCurved(id: UUID) {
        guard let i = edges.firstIndex(where: { $0.id == id }) else { return }
        edges[i].isCurved.toggle()
    }

    // MARK: - Connect mode

    func toggleConnectMode() {
        connectMode.toggle()
        connectSourceId = nil
        selectedNodeId  = nil
    }

    func handleNodeTap(_ nodeId: UUID) {
        if connectMode {
            if let source = connectSourceId {
                if source != nodeId {
                    // Avoid duplicate edges
                    let exists = edges.contains {
                        $0.fromNodeId == source && $0.toNodeId == nodeId
                    }
                    if !exists {
                        edges.append(CanvasEdge(from: source, to: nodeId))
                    }
                }
                connectSourceId = nil
            } else {
                connectSourceId = nodeId
            }
        } else {
            selectedNodeId = selectedNodeId == nodeId ? nil : nodeId
        }
    }

    // MARK: - Export

    /// Serialises the current canvas into the flat graph structure used by SDValidationService.
    func exportGraph() -> DesignGraph {
        let components = Array(Set(nodes.map { $0.type.rawValue }))
        let connections: [[String]] = edges.compactMap { edge in
            guard let from = nodes.first(where: { $0.id == edge.fromNodeId }),
                  let to   = nodes.first(where: { $0.id == edge.toNodeId }) else { return nil }
            return [from.type.rawValue, to.type.rawValue]
        }
        return DesignGraph(components: components, connections: connections)
    }

    // MARK: - Reset

    func reset() {
        nodes          = []
        edges          = []
        selectedNodeId = nil
        connectMode    = false
        connectSourceId = nil
    }
}
