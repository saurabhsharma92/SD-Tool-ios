//
//  CanvasToolbarView.swift
//  SDTool
//
//  Bottom toolbar for the design canvas: add blocks, toggle connect mode,
//  clear the canvas, and submit for validation.
//

import SwiftUI
import Combine

struct CanvasToolbarView: View {
    @ObservedObject var store: SDCanvasStore
    let isValidating: Bool
    let failedAttempts: Int
    @Binding var showPalette: Bool
    let onSubmit: () -> Void
    let onShowSolution: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Add block
            toolbarBtn(icon: "plus.square.fill", label: "Add", color: .accentColor) {
                showPalette = true
            }

            divider

            // Connect mode toggle
            toolbarBtn(
                icon:  "arrow.triangle.2.circlepath",
                label: "Connect",
                color: store.connectMode ? .orange : .primary
            ) {
                store.toggleConnectMode()
            }
            .background(
                store.connectMode
                    ? RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.5), lineWidth: 1.5)
                    : nil
            )

            divider

            // Clear all
            toolbarBtn(icon: "trash", label: "Clear", color: .red) {
                store.reset()
            }
            .disabled(store.nodes.isEmpty)

            if failedAttempts >= 3 {
                divider
                toolbarBtn(icon: "lightbulb.fill", label: "Solution", color: .yellow) {
                    onShowSolution()
                }
            }

            Spacer()

            // Submit
            Button(action: onSubmit) {
                HStack(spacing: 6) {
                    if isValidating {
                        ProgressView().scaleEffect(0.75)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text("Submit")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .disabled(store.nodes.isEmpty || isValidating)
            .padding(.trailing, 12)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Helpers

    private var divider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(width: 0.5, height: 28)
            .padding(.horizontal, 4)
    }

    private func toolbarBtn(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 20))
                Text(label).font(.system(size: 10))
            }
            .foregroundStyle(color)
            .frame(width: 62, height: 44)
        }
    }
}
