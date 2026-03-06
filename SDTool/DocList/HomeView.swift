//
//  HomeView.swift
//  SDTool
//

import SwiftUI

struct HomeView: View {

    @ObservedObject private var progressStore = ReadingProgressStore.shared
    @ObservedObject private var likedStore    = LikedPostsStore.shared
    @StateObject   private var docStore       = DocStore()

    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {

                    // ── Stats row ──────────────────────────────────
                    statsRow

                    // ── In Progress ────────────────────────────────
                    if !progressStore.inProgress.isEmpty {
                        sectionHeader("In Progress", icon: "book.fill", color: .orange)
                        horizontalDocCards(progressStore.inProgress)
                    }

                    // ── Recently Read ──────────────────────────────
                    if !progressStore.completed.isEmpty {
                        sectionHeader("Completed", icon: "checkmark.seal.fill", color: .green)
                        horizontalDocCards(progressStore.completed)
                    }

                    // ── All Recent ─────────────────────────────────
                    if progressStore.recentlyOpened.isEmpty {
                        emptyState
                    }

                    // ── Liked Blogs ────────────────────────────────
                    if !likedStore.likedPosts.isEmpty {
                        sectionHeader("Liked Blogs", icon: "heart.fill", color: .red)
                        likedBlogsList
                    }

                    Spacer(minLength: 32)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Doc.self) { doc in
                DocReaderView(doc: doc)
            }
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatCard(
                value: "\(docStore.docs.count)",
                label: "Articles",
                icon:  "doc.text.fill",
                color: .indigo
            )
            StatCard(
                value: "\(progressStore.inProgress.count)",
                label: "In Progress",
                icon:  "book.fill",
                color: .orange
            )
            StatCard(
                value: "\(progressStore.completed.count)",
                label: "Completed",
                icon:  "checkmark.seal.fill",
                color: .green
            )
            StatCard(
                value: "\(likedStore.likedPosts.count)",
                label: "Liked",
                icon:  "heart.fill",
                color: .red
            )
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(color)
            Text(title).font(.title3).fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Horizontal doc cards

    private func horizontalDocCards(_ entries: [ArticleProgress]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(entries) { entry in
                    let doc = docStore.docs.first {
                        $0.url.lastPathComponent == entry.filename
                    }
                    if let doc {
                        NavigationLink(value: doc) {
                            ArticleProgressCard(entry: entry, doc: doc)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No reading activity yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Open an article in the Article tab to track your progress here.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Liked blogs list

    private var likedBlogsList: some View {
        VStack(spacing: 0) {
            let posts = Array(likedStore.likedPosts.prefix(5))
            ForEach(posts) { liked in
                Button {
                    if let url = liked.url { openURL(url) }
                } label: {
                    LikedBlogRow(liked: liked)
                        .padding(.horizontal, 16)
                }
                .tint(.primary)

                if liked.id != posts.last?.id {
                    Divider().padding(.leading, 72)
                }
            }

            if likedStore.likedPosts.count > 5 {
                NavigationLink(destination: LikedPostsView()) {
                    Text("See all \(likedStore.likedPosts.count) liked posts →")
                        .font(.subheadline)
                        .foregroundStyle(Color("AccentColor"))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }
}

// MARK: - Stat card

private struct StatCard: View {
    let value: String
    let label: String
    let icon:  String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Article progress card

private struct ArticleProgressCard: View {
    let entry: ArticleProgress
    let doc:   Doc

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Icon + progress ring
            ZStack {
                Circle()
                    .stroke(doc.iconColor.opacity(0.15), lineWidth: 4)
                    .frame(width: 52, height: 52)

                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(doc.iconColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.4), value: entry.progress)

                Image(systemName: doc.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(doc.iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .frame(width: 130, alignment: .leading)

                HStack(spacing: 4) {
                    Text("\(Int(entry.progress * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(doc.iconColor)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(entry.relativeDate)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14)
        .frame(width: 158)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Liked blog row

private struct LikedBlogRow: View {
    let liked: LikedPost

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(width: 40, height: 40)
                Text(liked.companyEmoji)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(liked.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Text(liked.companyName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !liked.relativeDate.isEmpty {
                        Text("·").foregroundStyle(.tertiary)
                        Text(liked.relativeDate)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Image(systemName: "heart.fill")
                .font(.system(size: 12))
                .foregroundStyle(.red)
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    HomeView()
}
