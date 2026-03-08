//
//  HomeView.swift
//  SDTool
//

import SwiftUI

struct HomeView: View {

    @ObservedObject private var progressStore = ReadingProgressStore.shared
    @ObservedObject private var likedStore    = LikedPostsStore.shared
    @ObservedObject private var blogStore     = BlogStore.shared
    @ObservedObject private var dailyPick     = DailyPickStore.shared
    @StateObject   private var docStore       = DocStore()
    @ObservedObject private var router        = NavigationRouter.shared

    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {

                    // ── Stats row ──────────────────────────────────
                    statsRow

                    // ── Daily picks ─────────────────────────────────
                    if dailyPick.articlePick != nil || dailyPick.blogPick != nil {
                        sectionHeader("Today's Picks", icon: "star.fill", color: .yellow)
                        VStack(spacing: 10) {
                            if let doc = dailyPick.articlePick {
                                Button { router.openArticle(doc) } label: {
                                    DailyArticlePickCard(doc: doc)
                                }
                                .buttonStyle(.plain)
                            }
                            if let blogPost = dailyPick.blogPick {
                                DailyBlogPickCard(pick: blogPost)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

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
            .onAppear {
                dailyPick.refreshArticle(docs: docStore.docs)
                loadBlogPickIfNeeded()
            }
            .onChange(of: docStore.docs.count) {
                dailyPick.refreshArticle(docs: docStore.docs)
            }
        }
    }

    // MARK: - Blog pick loader

    private func loadBlogPickIfNeeded() {
        // Only fetch if no blog pick saved for today
        guard dailyPick.blogPick == nil else { return }
        let subscribed = blogStore.subscribed.filter { !$0.browserOnly }
        guard !subscribed.isEmpty else { return }

        Task {
            var allPosts: [(company: BlogCompany, posts: [BlogPost])] = []
            for company in subscribed.prefix(6) { // check up to 6 companies for speed
                if let posts = await BlogFeedService.shared.cachedPosts(for: company),
                   !posts.isEmpty {
                    allPosts.append((company: company, posts: posts))
                }
            }
            await MainActor.run {
                if !allPosts.isEmpty {
                    dailyPick.refreshBlogPost(allPosts: allPosts)
                }
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
                        $0.filename == entry.filename
                    }
                    if let doc {
                        Button { router.openArticle(doc) } label: {
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
                    // Find the company for this liked post and deep-link to Blogs tab
                    let company = blogStore.companies.first {
                        $0.name == liked.companyName
                    }
                    if let company, !company.browserOnly {
                        router.blogDestination = company
                        router.selectedTab = 2
                    } else if let url = liked.url {
                        openURL(url)
                    }
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

// MARK: - Daily Article Pick Card

struct DailyArticlePickCard: View {
    let doc: Doc

    var body: some View {
        pickCard(
            emoji:    articleEmoji(doc),
            title:    doc.name,
            subtitle: doc.category,
            badge:    "Article",
            color:    doc.iconColor
        )
    }

    private func articleEmoji(_ doc: Doc) -> String {
        switch doc.icon {
        case "brain":                   return "🧠"
        case "message.fill":            return "💬"
        case "bolt.fill":               return "⚡️"
        case "externaldrive.fill":      return "💾"
        case "network":                 return "🌐"
        case "cylinder.split.1x2.fill": return "🗄️"
        case "cpu":                     return "⚙️"
        default:                        return "📄"
        }
    }
}

// MARK: - Daily Blog Post Pick Card

struct DailyBlogPickCard: View {
    let pick: DailyBlogPick
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            // Record as blog read then open the specific post
            ActivityStore.shared.recordBlogRead(
                companyName: pick.companyName,
                postTitle:   pick.postTitle
            )
            if let url = pick.postURL { openURL(url) }
        } label: {
            pickCard(
                emoji:    pick.companyEmoji,
                title:    pick.postTitle,
                subtitle: pick.companyName + " · " + pick.category,
                badge:    "Blog Post",
                color:    .orange
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared pick card layout

private func pickCard(
    emoji:    String,
    title:    String,
    subtitle: String,
    badge:    String,
    color:    Color
) -> some View {
    HStack(spacing: 14) {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.15))
                .frame(width: 56, height: 56)
            Text(emoji)
                .font(.system(size: 28))
        }
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(badge.uppercased())
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
                Text("of the day")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }
    .padding(14)
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(RoundedRectangle(cornerRadius: 16))
}

#Preview {
    HomeView()
}
