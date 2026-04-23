//
//  DesignGraph.swift
//  SDTool
//
//  Canvas data model: block types, nodes, edges, and the serialized snapshot
//  sent to validation.
//

import Foundation
import CoreGraphics

// MARK: - Block types

enum BlockType: String, CaseIterable, Codable, Identifiable {
    case input        = "Input"
    case server       = "Server"
    case rdbms        = "RDBMS"
    case nosql        = "NoSQL"
    case cache        = "Cache"
    case apiGateway   = "API Gateway"
    case cdn          = "CDN"
    case reverseProxy = "Reverse Proxy"
    case readReplica  = "Read Replicas"
    case writeReplica = "Write Replicas"
    case fileStorage  = "File Storage"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .input:        return "person.crop.circle.fill"
        case .server:       return "server.rack"
        case .rdbms:        return "cylinder.split.1x2.fill"
        case .nosql:        return "cylinder.fill"
        case .cache:        return "bolt.fill"
        case .apiGateway:   return "network"
        case .cdn:          return "globe.americas.fill"
        case .reverseProxy: return "arrow.left.arrow.right.circle.fill"
        case .readReplica:  return "square.3.layers.3d.down.right"
        case .writeReplica: return "square.3.layers.3d.down.left"
        case .fileStorage:  return "externaldrive.fill"
        }
    }
}

// MARK: - Scaling mode

enum ScalingMode: String, Codable {
    case none
    case horizontal
    case vertical
}

// MARK: - Canvas node

struct CanvasNode: Identifiable, Codable {
    let id: UUID
    var type: BlockType
    var posX: Double    // CGPoint stored as separate doubles for clean Codable
    var posY: Double
    var scalingMode: ScalingMode
    var label: String?        // user-assigned name; nil = show type rawValue
    var customHeight: CGFloat? // user-resized height; nil = use default

    var displayName: String { label ?? type.rawValue }

    var position: CGPoint {
        get { CGPoint(x: posX, y: posY) }
        set { posX = newValue.x; posY = newValue.y }
    }

    init(type: BlockType, position: CGPoint = CGPoint(x: 160, y: 220)) {
        self.id          = UUID()
        self.type        = type
        self.posX        = position.x
        self.posY        = position.y
        self.scalingMode = .none
        self.label       = nil
    }
}

// MARK: - Canvas edge

struct CanvasEdge: Identifiable, Codable {
    let id: UUID
    let fromNodeId: UUID
    let toNodeId: UUID
    var isDotted: Bool
    var isCurved: Bool

    init(from: UUID, to: UUID, isDotted: Bool = false, isCurved: Bool = false) {
        self.id         = UUID()
        self.fromNodeId = from
        self.toNodeId   = to
        self.isDotted   = isDotted
        self.isCurved   = isCurved
    }
}

// MARK: - Serialized snapshot (sent to validation)

struct DesignGraph {
    let components: [String]           // BlockType.rawValues with duplicates — count encodes quantity
    let connections: [[String]]        // [["Input","Server"], ...]
    let nodeLabels: [String: String]   // nodeId.uuidString → user-assigned label
}
