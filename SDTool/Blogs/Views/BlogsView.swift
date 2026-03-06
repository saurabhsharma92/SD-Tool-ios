//
//  BlogsView.swift
//  SDTool
//
//  Created by Saurabh Sharma on 3/5/26.
//

import SwiftUI

struct BlogsView: View {

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24, pinnedViews: .sectionHeaders) {
                    ForEach(BlogCatalog.categorized, id: \.category) { group in
                        Section {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(group.companies) { company in
                                    NavigationLink(value: company) {
                                        CompanyTileView(company: company)
                                    }
                                    .buttonStyle(.plain)
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
            .navigationTitle("Blogs")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: BlogCompany.self) { company in
                CompanyBlogView(company: company)
            }
        }
    }

    // MARK: - Category header

    private func categoryHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    BlogsView()
}
