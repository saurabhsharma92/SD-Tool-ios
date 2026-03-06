//
//  BlogPostRow.swift
//  SDTool
//
//  Created by Saurabh Sharma on 3/5/26.
//
import SwiftUI

struct BlogPostRow: View {
    let post:    BlogPost
    let company: BlogCompany

    @ObservedObject private var likedStore = LikedPostsStore.shared

    private var isLiked: Bool {
        likedStore.isLiked(urlString: post.url.absoluteString)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            // ── Post info ──────────────────────────────────────────
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

            Spacer()

            // ── Like button ────────────────────────────────────────
            Button {
                likedStore.toggleLike(post: post, company: company)
            } label: {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 18))
                    .foregroundStyle(isLiked ? .red : .secondary)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)
            }
            .buttonStyle(.borderless)
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
}
