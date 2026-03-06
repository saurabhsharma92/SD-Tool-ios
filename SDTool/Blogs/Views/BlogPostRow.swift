//
//  BlogPostRow.swift
//  SDTool
//
//  Created by Saurabh Sharma on 3/5/26.
//

import SwiftUI

struct BlogPostRow: View {
    let post: BlogPost

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            Text(post.title)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if let summary = post.summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !post.relativeDate.isEmpty {
                Text(post.relativeDate)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
