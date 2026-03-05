//
//  BlogsView.swift
//  SDTool
//
//  Created by Saurabh Sharma on 3/4/26.
//

import SwiftUI

struct BlogsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Blogs Coming Soon",
                systemImage: "newspaper",
                description: Text("Engineering blogs from top tech companies will appear here.")
            )
            .navigationTitle("Blogs")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    BlogsView()
}
