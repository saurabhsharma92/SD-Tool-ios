//
//  BlogAISheet.swift
//  SDTool
//

import SwiftUI
import MarkdownUI

enum BlogAIMode: String, CaseIterable {
    case summarize = "Summary"
    case eli5      = "Explain Simply"

    var icon: String {
        switch self {
        case .summarize: return "text.quote"
        case .eli5:      return "face.smiling"
        }
    }
}

struct BlogAISheet: View {
    let post:        BlogPost
    let initialMode: BlogAIMode           // passed in, not a binding

    @State private var mode:     BlogAIMode
    @State private var result:   String    = ""
    @State private var isLoading: Bool     = true
    @State private var error:    AIError?  = nil

    init(post: BlogPost, initialMode: BlogAIMode) {
        self.post        = post
        self.initialMode = initialMode
        _mode            = State(initialValue: initialMode)
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Debug: confirm view is alive
                let _ = print("[BlogAI] body rendered — isLoading: \(isLoading), result: \(result.count) chars, error: \(String(describing: error))")
                // Mode picker
                Picker("Mode", selection: $mode) {
                    ForEach(BlogAIMode.allCases, id: \.self) { m in
                        Label(m.rawValue, systemImage: m.icon).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                // Main content — fill all available space
                ZStack {
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView().scaleEffect(1.2)
                            Text(mode == .summarize
                                 ? "Fetching and summarising…"
                                 : "Simplifying the article…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Fetching the full post — may take a few seconds.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    } else if let err = error {
                        VStack(spacing: 16) {
                            Image(systemName: err.systemImage)
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text(err.localizedDescription ?? "Something went wrong.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Button("Try Again") { Task { await generate() } }
                                .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    } else if !result.isEmpty {
                        ScrollView {
                            Markdown(result)
                                .markdownTheme(.gitHub)
                                .padding(16)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(mode.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if !isLoading && !result.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: result, subject: Text(post.title)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .task(id: mode) { await generate() }   // re-fires whenever mode changes
        }
    }

    @MainActor
    private func generate() async {
        print("[BlogAI] generate() called — mode: \(mode), post: \(post.title)")
        isLoading = true
        error     = nil
        result    = ""

        do {
            // Step 1: try to fetch full article; fall back to RSS summary or just title
            let content: String = await fetchContent()
            print("[BlogAI] Content ready (\(content.count) chars), calling Gemini…")

            // Step 2: ask Gemini
            let text: String
            switch mode {
            case .summarize:
                text = try await GeminiService.shared.summarizeBlogPost(
                    title: post.title, content: content)
            case .eli5:
                text = try await GeminiService.shared.explainBlogPost(
                    title: post.title, content: content)
            }

            print("[BlogAI] Gemini response (\(text.count) chars): \(text.prefix(100))")
            result    = text
            isLoading = false
        } catch let aiErr as AIError {
            print("[BlogAI] AIError: \(aiErr)")
            error     = aiErr
            isLoading = false
        } catch {
            print("[BlogAI] Unknown error: \(error)")
            self.error = .from(error)
            isLoading  = false
        }
    }

    // Content strategy: RSS summary first (always available, no network needed),
    // then attempt full fetch as an upgrade, fall back gracefully.
    private func fetchContent() async -> String {
        print("[BlogAI] fetchContent() start — post: \(post.title)")

        // 1. Use RSS summary immediately if available (no extra network call needed)
        if let rss = post.summary, !rss.isEmpty {
            print("[BlogAI] Using RSS summary (\(rss.count) chars), will try to enrich…")
            // Try to get more content in background
            if let full = try? await BlogTextExtractor.shared.extract(from: post.url),
               full.count > rss.count {
                print("[BlogAI] Full fetch succeeded (\(full.count) chars)")
                return full
            }
            print("[BlogAI] Using RSS summary as final content")
            return rss
        }

        // 2. No RSS summary — must fetch
        print("[BlogAI] No RSS summary, attempting fetch…")
        do {
            let extracted = try await BlogTextExtractor.shared.extract(from: post.url)
            if !extracted.isEmpty {
                print("[BlogAI] Fetch succeeded (\(extracted.count) chars)")
                return extracted
            }
        } catch {
            print("[BlogAI] Fetch FAILED: \(error)")
        }

        // 3. Nothing worked — title only
        print("[BlogAI] Using title-only fallback")
        return "Blog post title: \(post.title). Published by \(post.url.host ?? "unknown")."
    }
}
