//
//  ArticleAISheet.swift
//  SDTool
//

import SwiftUI
import MarkdownUI

// MARK: - Mode

enum ArticleAIMode: String, CaseIterable {
    case summarize = "Summary"
    case eli5      = "Explain Simply"

    var icon: String {
        switch self {
        case .summarize: return "text.quote"
        case .eli5:      return "face.smiling"
        }
    }

    var emptyPrompt: String {
        switch self {
        case .summarize: return "Generating summary…"
        case .eli5:      return "Simplifying the article…"
        }
    }
}

// MARK: - Sheet

struct ArticleAISheet: View {
    let doc:         Doc
    let rawMarkdown: String
    @Binding var mode: ArticleAIMode

    @State private var result:    String  = ""
    @State private var isLoading: Bool    = false
    @State private var error:     AIError? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode picker
                Picker("Mode", selection: $mode) {
                    ForEach(ArticleAIMode.allCases, id: \.self) { m in
                        Label(m.rawValue, systemImage: m.icon).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                // Content
                ScrollView {
                    Group {
                        if isLoading {
                            loadingView
                        } else if let error {
                            errorView(error)
                        } else if result.isEmpty {
                            placeholderView
                        } else {
                            Markdown(result)
                                .markdownTheme(.gitHub)
                                .padding(16)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(mode.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if !isLoading && !result.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: result, subject: Text(doc.name)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .onChange(of: mode) { Task { await generate() } }
            .task { await generate() }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    AIQuotaBadge()
                }
            }
        }
    }

    // MARK: - Sub-views

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(mode.emptyPrompt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var placeholderView: some View {
        Text("Tap to generate")
            .foregroundStyle(.secondary)
            .padding(.top, 60)
    }

    private func errorView(_ err: AIError) -> some View {
        AIErrorView(
            error: err,
            onRetry: err.isRetryable ? { Task { await generate() } } : nil
        )
    }

    // MARK: - Generate

    @MainActor
    private func generate() async {
        guard !rawMarkdown.isEmpty else { return }
        isLoading = true
        error     = nil
        result    = ""

        do {
            let text: String
            switch mode {
            case .summarize:
                text = try await GeminiService.shared.summarizeForReading(rawMarkdown)
            case .eli5:
                text = try await GeminiService.shared.explainSimply(rawMarkdown, topic: doc.name)
            }
            result    = text
            isLoading = false
        } catch let aiErr as AIError {
            error     = aiErr
            isLoading = false
        } catch {
            self.error = .from(error)
            isLoading  = false
        }
    }
}
