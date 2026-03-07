//
//  CompanyTileView.swift
//  SDTool
//

import SwiftUI

struct CompanyTileView: View {
    let company: BlogCompany

    private var faviconURL: URL? {
        URL(string: "https://www.google.com/s2/favicons?domain=\(company.faviconDomain)&sz=64")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(company.color.opacity(0.12))
                    .frame(height: 72)

                AsyncImage(url: faviconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().interpolation(.high)
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    default:
                        Text(company.emoji).font(.system(size: 32))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Badge: safari for website-only, rss icon for feeds
                Image(systemName: company.blogType == .website ? "safari.fill" : "dot.radiowaves.left.and.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .frame(height: 72)

            Text(company.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
