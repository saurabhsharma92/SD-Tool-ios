//
//  ArticleChatView.swift
//  SDTool
//

import SwiftUI
import MarkdownUI

struct ArticleChatView: View {
    let doc:         Doc
    let rawMarkdown: String

    @State private var messages:       [ChatMessage] = []
    @State private var inputText:      String        = ""
    @State private var isResponding:   Bool          = false
    @State private var isLoadingCtx:   Bool          = false
    @State private var contextSummary: String        = ""
    @State private var error:          AIError?      = nil

    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool

    private let suggestions = [
        "What are the key trade-offs in this design?",
        "What's the most important concept to understand?",
        "What interview questions might come from this?",
        "What could go wrong with this approach?"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Context status banner
                contextBanner

                Divider()

                // Message list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty && !isLoadingCtx {
                                suggestionsView
                            }
                            ForEach(messages) { msg in
                                MessageBubble(message: msg)
                                    .id(msg.id)
                            }
                            if isResponding {
                                TypingIndicator()
                                    .id("typing")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: messages.count) {
                        if let last = messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onChange(of: isResponding) {
                        if isResponding {
                            withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                        }
                    }
                }

                Divider()

                // Input bar
                inputBar
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if !messages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { messages = [] } label: {
                            Image(systemName: "trash")
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear { loadContext() }
        }
    }

    // MARK: - Context banner

    private var contextBanner: some View {
        HStack(spacing: 10) {
            if isLoadingCtx {
                ProgressView().scaleEffect(0.8)
                Text("Loading article context…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if contextSummary.isEmpty {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text("Context unavailable — answers may be less accurate")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                Text("Article context loaded · \(doc.name)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Suggestions

    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ask anything about this article")
                .font(.headline)
                .padding(.bottom, 4)
            ForEach(suggestions, id: \.self) { s in
                Button {
                    inputText = s
                    send()
                } label: {
                    Text(s)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about this article…", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .focused($inputFocused)
                .onSubmit { send() }

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(canSend ? Color.indigo : Color.secondary)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !isResponding
        && !isLoadingCtx
    }

    // MARK: - Actions

    private func loadContext() {
        Task {
            // Check cache first
            if let cached = await ArticleSummaryCache.shared.get(doc.filename) {
                await MainActor.run { contextSummary = cached }
                return
            }
            guard !rawMarkdown.isEmpty else { return }
            await MainActor.run { isLoadingCtx = true }
            do {
                let summary = try await GeminiService.shared.summarizeForContext(rawMarkdown)
                await ArticleSummaryCache.shared.set(doc.filename, summary: summary)
                await MainActor.run { contextSummary = summary; isLoadingCtx = false }
            } catch {
                // Context failed — chat still works, just less accurate
                await MainActor.run { isLoadingCtx = false }
            }
        }
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isResponding else { return }

        let userMsg = ChatMessage(role: .user, text: text)
        messages.append(userMsg)
        inputText   = ""
        isResponding = true
        error        = nil

        Task {
            do {
                let reply = try await GeminiService.shared.chat(
                    history:       messages.dropLast(),   // exclude the msg we just added
                    newMessage:    text,
                    contextSummary: contextSummary
                )
                let aiMsg = ChatMessage(role: .assistant, text: reply)
                await MainActor.run { messages.append(aiMsg); isResponding = false }
            } catch let aiErr as AIError {
                await MainActor.run {
                    let errMsg = ChatMessage(role: .assistant,
                                            text: "⚠️ \(aiErr.localizedDescription ?? "Error")")
                    messages.append(errMsg)
                    isResponding = false
                }
            } catch {
                await MainActor.run {
                    let errMsg = ChatMessage(role: .assistant,
                                            text: "⚠️ Something went wrong. Please try again.")
                    messages.append(errMsg)
                    isResponding = false
                }
            }
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user { Spacer(minLength: 48) }

            if message.role == .assistant {
                // Avatar
                ZStack {
                    Circle().fill(Color.indigo.opacity(0.15)).frame(width: 28, height: 28)
                    Image(systemName: "sparkles").font(.system(size: 13)).foregroundStyle(.indigo)
                }
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 2) {
                if message.role == .assistant {
                    // Render markdown in AI responses
                    Markdown(message.text)
                        .markdownTheme(.gitHub)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(
                            RoundedRectangle(cornerRadius: 16)
                                .corners([.topLeft, .topRight, .bottomRight])
                        )
                } else {
                    Text(message.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.indigo)
                        .foregroundStyle(.white)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 16)
                                .corners([.topLeft, .topRight, .bottomLeft])
                        )
                }
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if message.role == .assistant { Spacer(minLength: 48) }
        }
    }
}

// MARK: - Typing indicator

private struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle().fill(Color.indigo.opacity(0.15)).frame(width: 28, height: 28)
                Image(systemName: "sparkles").font(.system(size: 13)).foregroundStyle(.indigo)
            }
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 7, height: 7)
                        .scaleEffect(phase == i ? 1.3 : 0.8)
                        .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15),
                                   value: phase)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            Spacer()
        }
        .onAppear { phase = 1 }
    }
}

// MARK: - RoundedRectangle corners helper

private extension RoundedRectangle {
    func corners(_ corners: UIRectCorner) -> some Shape {
        VariableCornerRoundedRectangle(cornerRadius: cornerSize.width, corners: corners)
    }
}

private struct VariableCornerRoundedRectangle: Shape {
    let cornerRadius: CGFloat
    let corners:      UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
        )
        return Path(path.cgPath)
    }
}
