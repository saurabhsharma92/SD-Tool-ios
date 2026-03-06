//
//  BlogsView.swift
//  SDTool
//

import SwiftUI

struct BlogsView: View {

    @ObservedObject private var likedStore    = LikedPostsStore.shared
    @ObservedObject private var categoryStore = BlogCategoryStore.shared

    @State private var isEditing = false

    @Environment(\.openURL) private var openURL

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if isEditing {
                    editView
                } else {
                    browseView
                }
            }
            .navigationTitle("Blogs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(destination: LikedPostsView()) {
                        HStack(spacing: 4) {
                            Image(systemName: likedStore.likedPosts.isEmpty
                                  ? "heart" : "heart.fill")
                                .foregroundStyle(.red)
                            if !likedStore.likedPosts.isEmpty {
                                Text("\(likedStore.likedPosts.count)")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        withAnimation { isEditing.toggle() }
                    }
                }
            }
            .navigationDestination(for: BlogCompany.self) { company in
                CompanyBlogView(company: company)
                    .id(company.id)
            }
        }
    }

    // MARK: - Browse view

    private var browseView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24, pinnedViews: .sectionHeaders) {
                ForEach(
                    BlogCatalog.categorized(orderedBy: categoryStore.categoryOrder),
                    id: \.category
                ) { group in
                    Section {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(group.companies) { company in
                                // Browser-only: tap opens Safari directly
                                if company.browserOnly {
                                    Button {
                                        openURL(company.websiteURL)
                                    } label: {
                                        CompanyTileView(company: company)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    NavigationLink(value: company) {
                                        CompanyTileView(company: company)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    } header: {
                        categoryHeader(group.category)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Edit view

    private var editView: some View {
        List {
            Section {
                ForEach(categoryStore.categoryOrder, id: \.self) { category in
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                        Text(category)
                        Spacer()
                        Text("\(companyCount(for: category)) companies")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .onMove(perform: categoryStore.move)
            } footer: {
                Text("Drag to reorder categories in the Blogs tab.")
            }

            Section {
                Button("Reset to Default Order") {
                    withAnimation { categoryStore.reset() }
                }
                .foregroundStyle(.red)
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Helpers

    private func categoryHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGroupedBackground))
    }

    private func companyCount(for category: String) -> Int {
        BlogCatalog.companies.filter { $0.category == category }.count
    }
}

#Preview {
    BlogsView()
}
