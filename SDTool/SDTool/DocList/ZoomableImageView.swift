//
//  ZoomableImageView.swift
//  SDTool
//

import SwiftUI

// MARK: - Full Screen Zoomable Overlay

struct ZoomableImageViewer: View {
    let url: URL
    @Binding var isPresented: Bool

    @State private var scale:        CGFloat = 1.0
    @State private var lastScale:    CGFloat = 1.0
    @State private var offset:       CGSize  = .zero
    @State private var lastOffset:   CGSize  = .zero
    @State private var imageLoaded:  Bool    = false

    var body: some View {
        ZStack {
            // Dimmed background — tap to dismiss
            Color.black.opacity(0.92)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Image
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = lastScale * value
                                    }
                                    .onEnded { value in
                                        lastScale = scale
                                        if scale < 1.0 {
                                            withAnimation(.spring()) {
                                                scale      = 1.0
                                                lastScale  = 1.0
                                                offset     = .zero
                                                lastOffset = .zero
                                            }
                                        }
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width:  lastOffset.width  + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                        // Snap back if scale is 1
                                        if scale <= 1.0 {
                                            withAnimation(.spring()) {
                                                offset     = .zero
                                                lastOffset = .zero
                                            }
                                        }
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > 1.0 {
                                    scale      = 1.0
                                    lastScale  = 1.0
                                    offset     = .zero
                                    lastOffset = .zero
                                } else {
                                    scale     = 2.5
                                    lastScale = 2.5
                                }
                            }
                        }

                case .failure:
                    VStack(spacing: 12) {
                        Image(systemName: "photo.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("Failed to load image")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }

                default:
                    ProgressView().tint(.white)
                }
            }
            .padding(16)

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                            .background(Color.black.opacity(0.3), in: Circle())
                    }
                    .padding(20)
                }
                Spacer()

                // Hint
                Text("Pinch to zoom · Double tap · Drag to pan")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.bottom, 32)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isPresented = false
        }
    }
}

// MARK: - Inline Tappable Image (used in Markdown rendering)

struct TappableAsyncImage: View {
    let url:       URL
    let maxHeight: CGFloat

    @State private var showViewer = false

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: maxHeight)
                    .cornerRadius(8)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
                            .padding(6)
                    }
                    .onTapGesture { showViewer = true }

            case .failure:
                HStack(spacing: 6) {
                    Image(systemName: "photo.slash")
                        .foregroundStyle(.secondary)
                    Text("Image unavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            default:
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 120)
                    .overlay(ProgressView())
            }
        }
        .fullScreenCover(isPresented: $showViewer) {
            ZoomableImageViewer(url: url, isPresented: $showViewer)
                .background(ClearBackground())
        }
    }
}

// Needed to make fullScreenCover background transparent
struct ClearBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Zoomable Snapshot Viewer (for Mermaid diagrams)

struct ZoomableSnapshotViewer: View {
    let image:       UIImage?
    @Binding var isPresented: Bool

    @State private var scale:      CGFloat = 1.0
    @State private var lastScale:  CGFloat = 1.0
    @State private var offset:     CGSize  = .zero
    @State private var lastOffset: CGSize  = .zero

    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()
                .onTapGesture { dismiss() }

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { scale = lastScale * $0 }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale < 1.0 {
                                        withAnimation(.spring()) {
                                            scale = 1.0; lastScale = 1.0
                                            offset = .zero; lastOffset = .zero
                                        }
                                    }
                                },
                            DragGesture()
                                .onChanged { offset = CGSize(
                                    width:  lastOffset.width  + $0.translation.width,
                                    height: lastOffset.height + $0.translation.height) }
                                .onEnded { _ in
                                    lastOffset = offset
                                    if scale <= 1.0 {
                                        withAnimation(.spring()) {
                                            offset = .zero; lastOffset = .zero
                                        }
                                    }
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            if scale > 1.0 {
                                scale = 1.0; lastScale = 1.0
                                offset = .zero; lastOffset = .zero
                            } else {
                                scale = 2.5; lastScale = 2.5
                            }
                        }
                    }
                    .padding(16)
            } else {
                ProgressView().tint(.white)
            }

            // Controls
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(20)
                }
                Spacer()
                Text("Pinch to zoom  ·  Double-tap  ·  Drag to pan")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.bottom, 32)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) { isPresented = false }
    }
}
