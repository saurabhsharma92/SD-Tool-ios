//
//  CompanyTileView.swift
//  SDTool
//
//  Created by Saurabh Sharma on 3/5/26.
//

import SwiftUI

struct CompanyTileView: View {
    let company: BlogCompany

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Icon area ──────────────────────────────────────────
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(company.color.opacity(0.12))
                    .frame(height: 72)

                Text(company.emoji)
                    .font(.system(size: 34))
            }

            // ── Name ───────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 2) {
                Text(company.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
