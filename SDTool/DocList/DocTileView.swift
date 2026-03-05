//
//  DocTileView.swift
//  SDTool
//
//  Created by Saurabh Sharma on 3/4/26.
//

import SwiftUI

struct DocTileView: View {
    let doc: Doc
    let onDownload: () -> Void

    // SF Symbol based on doc name keywords
    private var icon: String {
        let n = doc.name.lowercased()
        if n.contains("ai") || n.contains("machine")          { return "brain" }
        if n.contains("chat") || n.contains("message")        { return "message.fill" }
        if n.contains("cache") || n.contains("redis")         { return "bolt.fill" }
        if n.contains("drive") || n.contains("storage")       { return "externaldrive.fill" }
        if n.contains("network") || n.contains("api")         { return "network" }
        if n.contains("database") || n.contains("sql")        { return "cylinder.split.1x2.fill" }
        if n.contains("envelope") || n.contains("calculat")   { return "function" }
        if n.contains("design") || n.contains("system")       { return "cpu" }
        return "doc.text.fill"
    }

    // Accent color per category
    private var iconColor: Color {
        let n = doc.name.lowercased()
        if n.contains("ai") || n.contains("machine")          { return .purple }
        if n.contains("chat") || n.contains("message")        { return .green }
        if n.contains("cache") || n.contains("redis")         { return .orange }
        if n.contains("drive") || n.contains("storage")       { return .blue }
        if n.contains("envelope") || n.contains("calculat")   { return .teal }
        return .indigo
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Icon area ──────────────────────────────────────────
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconColor.opacity(0.12))
                    .frame(height: 80)

                Image(systemName: icon)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Download / saved badge top-right
                if doc.isDownloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)
                        .padding(8)
                } else {
                    Button(action: onDownload) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .padding(8)
                }
            }
            .frame(height: 80)

            // ── Title area ─────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(doc.url.lastPathComponent)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
