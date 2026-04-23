//
//  CanvasHelpView.swift
//  SDTool
//
//  Help sheet explaining how to use the Design Canvas.
//

import SwiftUI

struct CanvasHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HelpRow(
                        icon: "plus.circle.fill",
                        iconColor: .indigo,
                        title: "Add Blocks",
                        description: "Tap the + button in the bottom toolbar to open the block palette. Pick a component (Server, Cache, Database, etc.) to drop it on the canvas."
                    )
                    HelpRow(
                        icon: "hand.draw.fill",
                        iconColor: .blue,
                        title: "Drag Blocks",
                        description: "Press and drag any block to reposition it anywhere on the canvas."
                    )
                } header: { Text("Adding & Moving") }

                Section {
                    HelpRow(
                        icon: "pencil.circle.fill",
                        iconColor: .orange,
                        title: "Rename a Block",
                        description: "Long-press a block, then tap Rename. Give servers and other components meaningful names (e.g. \"Tweet Server\", \"User Feed Cache\"). Servers must be named before you can submit."
                    )
                    HelpRow(
                        icon: "arrow.left.and.right",
                        iconColor: .green,
                        title: "Horizontal Scaling",
                        description: "Long-press a block → Horizontal Scaling. The block expands to show ×3 instances side-by-side, representing a horizontally scaled service."
                    )
                    HelpRow(
                        icon: "arrow.up.and.down",
                        iconColor: .teal,
                        title: "Vertical Scaling",
                        description: "Long-press a block → Vertical Scaling. A green ↑ badge appears, representing a vertically scaled (beefier) instance."
                    )
                    HelpRow(
                        icon: "trash.fill",
                        iconColor: .red,
                        title: "Delete a Block",
                        description: "Long-press a block → Delete. You'll be asked to confirm before the block is removed."
                    )
                } header: { Text("Long Press Options") }

                Section {
                    HelpRow(
                        icon: "arrow.triangle.2.circlepath.circle.fill",
                        iconColor: .purple,
                        title: "Connect Mode",
                        description: "Tap the Connect (arrow) button in the bottom toolbar to enter connect mode. Tap the source block, then tap the destination block to draw an arrow between them."
                    )
                    HelpRow(
                        icon: "arrow.left.and.right.circle.fill",
                        iconColor: .cyan,
                        title: "Edit Arrows",
                        description: "While in connect mode, long-press an existing arrow to: delete it, reverse its direction, make it dotted (async), or make it curved."
                    )
                    HelpRow(
                        icon: "xmark.circle",
                        iconColor: .secondary,
                        title: "Exit Connect Mode",
                        description: "Tap Cancel in the connect-mode banner at the top, or tap the connect button again."
                    )
                } header: { Text("Connections") }

                Section {
                    HelpRow(
                        icon: "checkmark.seal.fill",
                        iconColor: .green,
                        title: "Submit Your Design",
                        description: "Tap Check in the bottom toolbar when you're done. The app scores your design against the required components and connections, and provides AI feedback."
                    )
                    HelpRow(
                        icon: "lightbulb.fill",
                        iconColor: .orange,
                        title: "Constraints Banner",
                        description: "The orange banner at the top shows the problem constraints. Tap the ⓘ button in the top-right to show or hide it."
                    )
                    HelpRow(
                        icon: "clock.arrow.circlepath",
                        iconColor: .indigo,
                        title: "Attempt History",
                        description: "Tap the clock button in the top-right to review your previous submissions for this level."
                    )
                } header: { Text("Submitting") }

                Section {
                    HelpRow(
                        icon: "network",
                        iconColor: .purple,
                        title: "API Gateway / Reverse Proxy",
                        description: "These blocks are tall and narrow by design — position them between your clients and servers to show they span multiple backend instances."
                    )
                    HelpRow(
                        icon: "pencil.circle.fill",
                        iconColor: .orange,
                        title: "Orange Pencil Badge",
                        description: "A small orange pencil badge on a Server block means it needs a meaningful name. Long-press → Rename before submitting."
                    )
                } header: { Text("Tips") }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("How to Use the Canvas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Help Row

private struct HelpRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 28)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}
