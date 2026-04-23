//
//  DesignCanvasView.swift
//  SDTool
//
//  Main interactive canvas where users drag and connect building blocks.
//  Uses coordinateSpace(name: "canvas") so DragGesture.location always reflects
//  the canvas coordinate space, matching the .position() modifier on each node.
//

import SwiftUI
import FirebaseAuth
import Combine

struct DesignCanvasView: View {
    let problem: SDProblem
    let level: SDLevel

    @StateObject private var canvasStore   = SDCanvasStore()
    @ObservedObject private var progressStore = SDProgressStore.shared
    @ObservedObject private var authStore     = AuthStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showPalette:       Bool             = false
    @State private var showConstraints:   Bool             = true
    @State private var showValidation:    Bool             = false
    @State private var isValidating:      Bool             = false
    @State private var validationResult:  ValidationResult? = nil
    @State private var canvasSize:        CGSize           = .zero
    @State private var levelJustCompleted: Bool            = false
    @State private var showHistory:        Bool            = false
    @State private var showSolution:       Bool            = false
    @State private var failedAttempts:     Int             = 0
    @State private var renameNodeId:       UUID?           = nil
    @State private var renameDraft:        String          = ""
    @State private var showRename:         Bool            = false
    @State private var nodeToDelete:       UUID?           = nil
    @State private var showDeleteAlert:    Bool            = false
    @State private var showHelp:           Bool            = false
    @State private var showUnnamedAlert:   Bool            = false

    var body: some View {
        VStack(spacing: 0) {
            // Collapsible constraints banner
            if showConstraints {
                constraintsBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Canvas
            GeometryReader { geo in
                ZStack {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()

                    // 1. Edge layer (non-interactive arrows)
                    EdgeCanvasLayer(nodes: canvasStore.nodes, edges: canvasStore.edges)

                    // 2. Edge interaction (long-press: delete/reverse/style) — connect mode only
                    if canvasStore.connectMode {
                        EdgeInteractionLayer(
                            nodes:          canvasStore.nodes,
                            edges:          canvasStore.edges,
                            onDelete:       { canvasStore.deleteEdge(id: $0) },
                            onReverse:      { canvasStore.reverseEdge(id: $0) },
                            onToggleDotted: { canvasStore.toggleDotted(id: $0) },
                            onToggleCurved: { canvasStore.toggleCurved(id: $0) }
                        )
                    }

                    // 3. Connect mode instruction overlay
                    if canvasStore.connectMode {
                        connectModeOverlay
                    }

                    // 4. Node layer
                    ForEach(canvasStore.nodes) { node in
                        BlockNodeView(
                            node:            node,
                            isSelected:      canvasStore.selectedNodeId  == node.id,
                            isConnectSource: canvasStore.connectSourceId == node.id,
                            onTap:           { canvasStore.handleNodeTap(node.id) },
                            onDelete:        {
                                nodeToDelete    = node.id
                                showDeleteAlert = true
                            },
                            onSetScaling:    { mode in canvasStore.setScaling(id: node.id, mode: mode) },
                            onRename:        { draft in
                                renameNodeId = node.id
                                renameDraft  = draft
                                showRename   = true
                            },
                            onResize:        { height in canvasStore.resizeNode(id: node.id, height: height) }
                        )
                        .position(node.position)
                        .gesture(
                            DragGesture(coordinateSpace: .named("canvas"))
                                .onChanged { val in
                                    canvasStore.moveNode(id: node.id, to: val.location)
                                }
                        )
                    }

                    // 3. Empty-state hint
                    if canvasStore.nodes.isEmpty {
                        emptyState
                    }
                }
                .coordinateSpace(name: "canvas")
                .onAppear { canvasSize = geo.size }
            }

            // Bottom toolbar
            CanvasToolbarView(
                store:          canvasStore,
                isValidating:   isValidating,
                failedAttempts: failedAttempts,
                showPalette:    $showPalette,
                onSubmit:       { Task { await submit() } },
                onShowSolution: { showSolution = true }
            )
        }
        .navigationTitle(level.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 14) {
                    Button {
                        showHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showConstraints.toggle() }
                    } label: {
                        Image(systemName: showConstraints ? "info.circle.fill" : "info.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showHistory) {
            AttemptHistoryView(problem: problem, level: level)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSolution) {
            SolutionView(level: level)
                .presentationDetents([.medium, .large])
        }
        // Block palette sheet
        .sheet(isPresented: $showPalette) {
            BlockPaletteSheet { blockType in
                let center = canvasSize == .zero
                    ? CGPoint(x: 160, y: 220)
                    : CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let jitter = CGPoint(
                    x: center.x + Double.random(in: -50...50),
                    y: center.y + Double.random(in: -50...50)
                )
                canvasStore.addNode(type: blockType, at: jitter)
                showPalette = false
            }
            .presentationDetents([.medium])
        }
        // Rename node sheet
        .sheet(isPresented: $showRename) {
            NavigationStack {
                Form {
                    Section("Component Name") {
                        TextField("e.g. Tweet Server", text: $renameDraft)
                            .autocorrectionDisabled()
                    }
                }
                .navigationTitle("Rename Block")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showRename = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if let id = renameNodeId {
                                canvasStore.renameNode(id: id, label: renameDraft)
                            }
                            showRename = false
                        }
                    }
                }
            }
            .presentationDetents([.height(200)])
        }
        // Delete confirmation
        .alert("Delete Block", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let id = nodeToDelete { canvasStore.deleteNode(id: id) }
                nodeToDelete = nil
            }
            Button("Cancel", role: .cancel) { nodeToDelete = nil }
        } message: {
            Text("Are you sure you want to remove this block?")
        }
        // Unnamed server warning
        .alert("Name Your Servers", isPresented: $showUnnamedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please give each Server a meaningful name (e.g. \"Tweet Server\", \"Feed Server\") before submitting. Long-press a block and tap Rename.")
        }
        // Help sheet
        .sheet(isPresented: $showHelp) {
            CanvasHelpView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        // Validation result sheet
        .sheet(isPresented: $showValidation, onDismiss: {
            if levelJustCompleted { dismiss() }
        }) {
            if let result = validationResult {
                ValidationResultView(
                    result:   result,
                    problem:  problem,
                    level:    level,
                    onDismiss: { showValidation = false },
                    onLevelComplete: {
                        levelJustCompleted = true
                        Task {
                            if let uid = authStore.user?.uid {
                                await progressStore.markLevelComplete(
                                    level.levelNumber,
                                    for: problem.id,
                                    userId: uid,
                                    feedback: result.aiFeedback ?? result.fallbackHint
                                )
                            }
                        }
                    }
                )
            }
        }
    }

    // MARK: - Subviews

    private var constraintsBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 13))
                .padding(.top, 1)
            Text(level.constraints)
                .font(.footnote)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
    }

    private var connectModeOverlay: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: canvasStore.connectSourceId == nil
                      ? "hand.tap.fill" : "arrow.right.circle.fill")
                    .foregroundStyle(.orange)
                Text(canvasStore.connectSourceId == nil
                     ? "Tap a block to start the connection"
                     : "Now tap the destination block")
                    .font(.footnote.weight(.medium))
                Spacer()
                Button("Cancel") { canvasStore.toggleConnectMode() }
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.orange.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.top, 10)
            Spacer()
        }
        .allowsHitTesting(false)  // let taps pass through to nodes below
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "plus.square.dashed")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("Tap + to add building blocks")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Submit

    private func submit() async {
        guard !canvasStore.nodes.isEmpty, !isValidating else { return }

        // Require meaningful names on all Server nodes
        let unnamedServers = canvasStore.nodes.filter { $0.type == .server && $0.label == nil }
        if !unnamedServers.isEmpty {
            showUnnamedAlert = true
            return
        }

        isValidating = true

        let graph   = canvasStore.exportGraph()
        let isGuest = authStore.isGuest

        let result = await SDValidationService.shared.validate(
            graph:        graph,
            level:        level,
            isGuest:      isGuest,
            userId:       authStore.user?.uid,
            problemId:    problem.id,
            problemTitle: problem.title
        )

        if !result.passed { failedAttempts += 1 }
        validationResult = result
        isValidating     = false
        showValidation   = true
    }
}
