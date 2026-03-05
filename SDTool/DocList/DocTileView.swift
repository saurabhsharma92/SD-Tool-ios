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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Icon area ──────────────────────────────────────────
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(doc.iconColor.opacity(0.12))
                    .frame(height: 80)

                Image(systemName: doc.icon)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(doc.iconColor)
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

//                Text(doc.url.lastPathComponent)
//                    .font(.caption2)
//                    .foregroundStyle(.tertiary)
//                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
