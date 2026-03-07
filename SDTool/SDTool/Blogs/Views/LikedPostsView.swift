//
//  LikedPostsView.swift
//  SDTool
//
//  Created by Saurabh Sharma on 3/5/26.
//

import SwiftUI

struct LikedPostsView: View {
    @ObservedObject private var likedStore = LikedPostsStore.shared
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if likedStore.likedPosts.isEmpty {
                ContentUnavailableView(
                    "No Liked Posts",
                    systemImage: "heart",
                    description: Text("Tap the ♡ on any blog post to save it here.")
                )
            } else {
                List {
                    ForEach(likedStore.likedPosts) { liked in
                        Button {
                            if let url = liked.url { openURL(url) }
                        } label: {
                            likedRow(liked)
                        }
                        .tint(.primary)
                    }
                    .onDelete { offsets in
                        offsets.forEach { i in
                            likedStore.unlike(urlString: likedStore.likedPosts[i].urlString)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Liked Posts")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !likedStore.likedPosts.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear All", role: .destructive) {
                        likedStore.unlikeAll()
                    }
                    .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Row

    private func likedRow(_ liked: LikedPost) -> some View {
        HStack(spacing: 12) {
            // Company emoji badge
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(width: 40, height: 40)
                Text(liked.companyEmoji)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(liked.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(liked.companyName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !liked.relativeDate.isEmpty {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(liked.relativeDate)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Image(systemName: "heart.fill")
                .font(.system(size: 14))
                .foregroundStyle(.red)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        LikedPostsView()
    }
}
