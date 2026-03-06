//
//  CompanyTileView.swift
//  SDTool
//

import SwiftUI

struct CompanyTileView: View {
    let company: BlogCompany

    private var faviconURL: URL? {
        let domain = company.websiteURL.host ?? ""
        return URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=64")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Icon area ──────────────────────────────────────────
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(company.color.opacity(0.12))
                    .frame(height: 72)

                AsyncImage(url: faviconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    default:
                        Text(company.emoji)
                            .font(.system(size: 32))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Safari badge for browser-only companies
                if company.browserOnly {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .padding(7)
                }
            }
            .frame(height: 72)

            // ── Name ───────────────────────────────────────────────
            Text(company.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
