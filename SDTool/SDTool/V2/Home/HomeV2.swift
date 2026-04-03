//
//  HomeV2.swift
//  SDTool
//
//  New home screen (v2 redesign).
//  Horizontal scrollable tab strip: Favorites | Articles | [Companies alphabetically, pinned first] | [Custom feeds] | + Add
//

import SwiftUI

// MARK: - Tab identity

enum HomeTab: Hashable {
    case favorites
    case articles
    case company(BlogCompany)
    case companyGroup(CompanyGroup)
    case customFeed(CustomRSSFeed)
    case addFeed
}

// MARK: - HomeV2

struct HomeV2: View {
    @ObservedObject private var blogStore   = BlogStore.shared
    @ObservedObject private var visibility  = CompanyVisibilityStore.shared
    @ObservedObject private var authStore   = AuthStore.shared
    @ObservedObject private var router      = NavigationRouter.shared

    @State private var selectedTab: HomeTab  = .favorites
    @State private var showAddFeed: Bool     = false
    @State private var showSyncAlert: Bool   = false

    @State private var browserOnlyURL: IdentifiableURL? = nil
    @State private var groupingCompany: BlogCompany?    = nil
    @State private var newGroupName: String             = ""
    @State private var showNewGroupAlert: Bool          = false

    // Tabs derived from store state
    private var companyTabs: [BlogCompany] {
        visibility.sorted(blogStore.companies.filter { visibility.isEnabled($0.name) })
    }

    private var allTabs: [HomeTab] {
        let companies = companyTabs
        let pinnedCompanies   = companies.filter {  visibility.isPinned($0.name) }.map { HomeTab.company($0) }
        let unpinnedCompanies = companies.filter { !visibility.isPinned($0.name) }.map { HomeTab.company($0) }

        let groups = visibility.sortedGroups()
        let pinnedGroups   = groups.filter {  visibility.isGroupPinned($0.id) }.map { HomeTab.companyGroup($0) }
        let unpinnedGroups = groups.filter { !visibility.isGroupPinned($0.id) }.map { HomeTab.companyGroup($0) }

        var tabs: [HomeTab] = [.favorites, .articles]
        tabs += pinnedCompanies
        tabs += pinnedGroups
        tabs += unpinnedCompanies
        tabs += unpinnedGroups
        tabs += visibility.customFeeds.map { .customFeed($0) }
        tabs.append(.addFeed)
        return tabs
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            Divider()
            tabStrip
            Divider()
            tabContent.inAppBrowser()
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showAddFeed) { RSSFeedSheet() }
        .sheet(item: $browserOnlyURL) { SafariView(url: $0.url).ignoresSafeArea() }
.alert("New Group", isPresented: $showNewGroupAlert) {
            TextField("Group name", text: $newGroupName)
            Button("Create") { createGroup() }
            Button("Cancel", role: .cancel) { groupingCompany = nil; newGroupName = "" }
        } message: {
            Text("Enter a name for the new group.")
        }
        .onChange(of: router.homeTabTrigger) { _, _ in
            withAnimation(.easeInOut(duration: 0.15)) { selectedTab = .favorites }
        }
        .task {
            // Always sync on first appear to pick up remote index changes
            blogStore.sync()
        }
    }

    private var navBar: some View {
        ZStack {
            Text("System Design Refresher")
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
            HStack {
                Spacer()
                if blogStore.isSyncing {
                    ProgressView().scaleEffect(0.75)
                } else {
                    Button { blogStore.sync() } label: {
                        Image(systemName: "arrow.clockwise").font(.system(size: 16))
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var tabStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(allTabs, id: \.self) { tab in
                        TabStripItem(
                            tab:        tab,
                            isSelected: selectedTab == tab,
                            isPinned:   isPinned(tab),
                            onTap:      { handleTabTap(tab) },
                            onLongPress: { handleLongPress(tab) },
                            onGroup:    { c in groupingCompany = c; showNewGroupAlert = true }
                        )
                        .id(tab)
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(height: 42)
            .background(Color(.systemBackground))
            .onChange(of: selectedTab) { _, tab in
                withAnimation { proxy.scrollTo(tab, anchor: .center) }
            }
        }
    }

    private func handleTabTap(_ tab: HomeTab) {
        if case .company(let c) = tab, c.browserOnly {
            browserOnlyURL = IdentifiableURL(url: c.websiteURL)
        } else {
            withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
            if tab == .addFeed { showAddFeed = true; selectedTab = .favorites }
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .favorites:
            FavoritesTabV2()

        case .articles:
            ArticlesTabV2()

        case .company(let company):
            CompanyTabV2(company: company)
                .id(company.id)   // force re-create when company changes

        case .companyGroup(let group):
            CompanyGroupTabV2(group: group)
                .id(group.id)

        case .customFeed(let feed):
            CustomFeedTabV2(feed: feed)
                .id(feed.id)

        case .addFeed:
            FavoritesTabV2()   // fallback while sheet is opening
        }
    }

    // MARK: - Helpers

    private func isPinned(_ tab: HomeTab) -> Bool {
        if case .company(let c)      = tab { return visibility.isPinned(c.name) }
        if case .companyGroup(let g) = tab { return visibility.isGroupPinned(g.id) }
        return false
    }

    private func handleLongPress(_ tab: HomeTab) {
        if case .company(let c) = tab {
            visibility.togglePin(c.name)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func createGroup() {
        let trimmed = newGroupName.trimmingCharacters(in: .whitespaces)
        guard let c = groupingCompany, !trimmed.isEmpty else {
            groupingCompany = nil; newGroupName = ""; return
        }
        visibility.addGroup(CompanyGroup(name: trimmed, companyNames: [c.name]))
        groupingCompany   = nil
        newGroupName      = ""
        showNewGroupAlert = false
    }
}

// MARK: - Tab strip item

private struct TabStripItem: View {
    let tab:         HomeTab
    let isSelected:  Bool
    let isPinned:    Bool
    let onTap:       () -> Void
    let onLongPress: () -> Void
    let onGroup:     ((BlogCompany) -> Void)?
    @ObservedObject private var visibility = CompanyVisibilityStore.shared

    var body: some View {
        switch tab {
        case .favorites, .articles, .company, .companyGroup:
            pillBody
        default:
            standardTabBody
        }
    }

    // Standard tab: icon + label + underline (CustomFeed, Add)
    private var standardTabBody: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                tabIcon
                tabLabel
            }
            .padding(.horizontal, 14)
            .frame(height: 38)

            Rectangle()
                .fill(isSelected ? Color.primary : Color.clear)
                .frame(height: 2)
        }
        .contentShape(Rectangle())
        .foregroundStyle(isSelected ? .primary : .secondary)
        .onTapGesture { onTap() }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in onLongPress() }
        )
    }

    // Pill tab: icon only, capsule background (Favorites, Articles, Companies)
    private var pillBody: some View {
        pillIcon
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(isSelected ? Color.primary.opacity(0.1) : Color.clear)
            )
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? Color.primary.opacity(0.25) : Color.clear,
                    lineWidth: 1
                )
            )
            .overlay(alignment: .topTrailing) {
                if isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                        .offset(x: 2, y: -2)
                }
            }
            .frame(height: 38)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
            .contextMenu {
                if case .company(let c) = tab {
                    Button {
                        visibility.togglePin(c.name)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin")
                    }

                    // Group menu
                    Menu {
                        Button {
                            onGroup?(c)
                        } label: {
                            Label("New Group…", systemImage: "folder.badge.plus")
                        }
                        ForEach(visibility.companyGroups) { group in
                            Button {
                                visibility.addToGroup(companyName: c.name, groupID: group.id)
                            } label: {
                                Label("Add to \(group.name)", systemImage: "folder")
                            }
                        }
                    } label: {
                        Label("Group", systemImage: "folder")
                    }

                    Divider()

                    Button(role: .destructive) {
                        visibility.setEnabled(c.name, enabled: false)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label("Hide", systemImage: "eye.slash")
                    }
                } else if case .companyGroup(let group) = tab {
                    Button {
                        visibility.toggleGroupPin(group.id)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin")
                    }
                    Button(role: .destructive) {
                        visibility.removeGroup(id: group.id)
                    } label: {
                        Label("Delete Group", systemImage: "folder.badge.minus")
                    }
                }
            }
    }

    @ViewBuilder
    private var pillIcon: some View {
        switch tab {
        case .favorites:
            Image(systemName: "heart.fill")
                .font(.system(size: 16))
                .foregroundStyle(isSelected ? .red : Color(.tertiaryLabel))
        case .articles:
            ArticlesIcon(size: 20, color: isSelected ? .indigo : Color(.tertiaryLabel))
        case .company(let c):
            FaviconView(domain: c.faviconDomain, fallback: c.emoji, size: 22)
        case .companyGroup:
            Image(systemName: "folder.fill")
                .font(.system(size: 16))
                .foregroundStyle(isSelected ? .indigo : Color(.tertiaryLabel))
        default:
            EmptyView()
        }
    }

    // Only used by standardTabBody (CustomFeed, Add)
    @ViewBuilder
    private var tabIcon: some View {
        switch tab {
        case .customFeed:
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? .primary : Color(.tertiaryLabel))
        case .addFeed:
            Image(systemName: "plus.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var tabLabel: some View {
        switch tab {
        case .customFeed(let f):
            Text(f.displayName)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
        case .addFeed:
            Text("Add")
                .font(.system(size: 13))
        default:
            EmptyView()
        }
    }
}

// MARK: - Articles icon (custom drawn)

struct ArticlesIcon: View {
    let size:  CGFloat
    let color: Color

    var body: some View {
        VStack(spacing: size * 0.13) {
            // Title line (wider)
            RoundedRectangle(cornerRadius: size * 0.08)
                .frame(width: size * 0.78, height: size * 0.14)
            // Body lines
            RoundedRectangle(cornerRadius: size * 0.08)
                .frame(width: size * 0.78, height: size * 0.11)
            RoundedRectangle(cornerRadius: size * 0.08)
                .frame(width: size * 0.78, height: size * 0.11)
            // Short last line
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: size * 0.08)
                    .frame(width: size * 0.46, height: size * 0.11)
                Spacer()
            }
            .frame(width: size * 0.78)
        }
        .foregroundStyle(color)
        .frame(width: size, height: size)
    }
}

// MARK: - Favicon view

struct FaviconView: View {
    let domain:   String
    let fallback: String
    let size:     CGFloat

    @State private var image: UIImage? = nil
    @State private var failed = false

    private var faviconURL: URL? {
        URL(string: "https://www.google.com/s2/favicons?sz=64&domain=\(domain)")
    }

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            } else {
                Text(fallback)
                    .font(.system(size: size * 0.75))
            }
        }
        .task(id: domain) {
            guard !failed, image == nil, let url = faviconURL else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let img = UIImage(data: data) {
                    image = img
                } else {
                    failed = true
                }
            } catch {
                failed = true
            }
        }
    }
}
