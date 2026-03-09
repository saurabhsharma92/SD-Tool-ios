//
//  GeminiService.swift
//  SDTool
//

import FirebaseAI
import SwiftUI

actor GeminiService {
    static let shared = GeminiService()

    // In-flight deduplication: if the same article triggers two AI calls at once,
    // the second caller awaits the first task rather than firing a new network request.
    private var inFlight: [String: Task<String, Error>] = [:]

    private init() {}

    // Builds a fresh model instance reading the current model selection from UserDefaults.
    // Called inside each request so a settings change takes effect on the next call.
    private func currentModel() -> GenerativeModel {
        let raw   = UserDefaults.standard.string(forKey: AppSettings.Key.geminiModel)
                    ?? AppSettings.Default.geminiModel
        let model = AppSettings.GeminiModel(rawValue: raw) ?? .flashLite
        let ai    = FirebaseAI.firebaseAI(backend: .googleAI())
        return ai.generativeModel(modelName: model.modelName)
    }

    // MARK: - Deduplication helper
    private func deduplicated(
        key: String,
        work: @escaping @Sendable () async throws -> String
    ) async throws -> String {
        if let existing = inFlight[key] {
            #if DEBUG
            print("[Gemini] Reusing in-flight request for key: \(key.prefix(40))…")
            #endif
            return try await existing.value
        }
        let task = Task<String, Error> { try await work() }
        inFlight[key] = task
        defer { inFlight.removeValue(forKey: key) }
        return try await task.value
    }

    // MARK: - Article: summarise for context (chat system prompt, not shown to user)

    func summarizeForContext(_ markdown: String) async throws -> String {
        let key = "ctx-" + String(markdown.prefix(120))
        return try await deduplicated(key: key) {
            let prompt = """
            Summarize this technical article in 3–5 concise paragraphs (under 400 words).
            Preserve all key concepts, terminology, numbers, and architectural decisions.
            Output plain text only — no markdown, no bullet points.

            ARTICLE:
            \(String(markdown.prefix(14_000)))
            """
            let result = try await self.generate(prompt)
            await self.chargeQuota(.chat)   // context load counts as 1 chat request
            return result
        }
    }

    // MARK: - Article: summarise for reading (shown to user, formatted markdown)

    func summarizeForReading(_ markdown: String) async throws -> String {
        let key = "read-" + String(markdown.prefix(120))
        return try await deduplicated(key: key) {
            let prompt = """
            Write a clear, well-structured summary of this technical article for an engineer.
            Start with one sentence stating what the article covers.
            Then list the most important points as bullet points (use • prefix).
            Finish with a one-line "Key takeaway:".
            Use **bold** for important terms. Keep it under 300 words.

            ARTICLE:
            \(String(markdown.prefix(14_000)))
            """
            let result = try await self.generate(prompt)
            await self.chargeQuota(.summary)
            return result
        }
    }

    // MARK: - Article: ELI5

    func explainSimply(_ markdown: String, topic: String) async throws -> String {
        let key = "eli5-" + topic + "-" + String(markdown.prefix(80))
        return try await deduplicated(key: key) {
            let prompt = """
            Explain the main ideas of this technical article to someone with no tech background.
            Use simple words, short sentences, and one everyday analogy.
            Avoid all jargon. Imagine explaining to a curious 12-year-old.
            Structure: one opening sentence, then 3–4 short paragraphs. Under 250 words.

            TOPIC: \(topic)
            ARTICLE:
            \(String(markdown.prefix(14_000)))
            """
            let result = try await self.generate(prompt)
            await self.chargeQuota(.explain)
            return result
        }
    }

    // MARK: - Article chat (multi-turn)

    func chat(
        history: [ChatMessage],
        newMessage: String,
        contextSummary: String
    ) async throws -> String {
        var contents: [ModelContent] = []

        let systemContext = """
        You are a helpful technical mentor. The user is studying the following article.
        Answer questions accurately and concisely. If something is not covered in the article, say so.
        Do not make things up. Use markdown formatting in your answers (bold, code blocks, bullet points).

        ARTICLE SUMMARY:
        \(contextSummary)
        """
        contents.append(ModelContent(role: "user",  parts: [TextPart(systemContext)]))
        contents.append(ModelContent(role: "model", parts: [TextPart("Got it — I've read the article summary and I'm ready to help. What would you like to know?")]))

        let recentHistory = history.suffix(20)
        for msg in recentHistory {
            contents.append(ModelContent(
                role: msg.role == .user ? "user" : "model",
                parts: [TextPart(msg.text)]
            ))
        }
        contents.append(ModelContent(role: "user", parts: [TextPart(newMessage)]))

        let result = try await generate(contents)
        await chargeQuota(.chat)
        return result
    }

    // MARK: - Blog: summarise post

    func summarizeBlogPost(title: String, content: String) async throws -> String {
        #if DEBUG
        print("[Gemini] summarizeBlogPost — \(title), \(content.count) chars")
        #endif
        let prompt = """
        Summarize this blog post for a software engineer.
        Start with one sentence stating the main point.
        Then list 3–5 key insights as bullet points (use • prefix).
        Use **bold** for important terms. Under 200 words.

        TITLE: \(title)
        CONTENT:
        \(String(content.prefix(10_000)))
        """
        let result = try await generate(prompt)
        await chargeQuota(.blog)
        return result
    }

    // MARK: - Blog: ELI5

    func explainBlogPost(title: String, content: String) async throws -> String {
        #if DEBUG
        print("[Gemini] explainBlogPost — \(title), \(content.count) chars")
        #endif
        let prompt = """
        Explain the key idea of this blog post to someone who doesn't work in tech.
        Use simple language, short sentences, and one everyday analogy.
        No jargon. Engaging and friendly tone. Under 200 words.

        TITLE: \(title)
        CONTENT:
        \(String(content.prefix(10_000)))
        """
        let result = try await generate(prompt)
        await chargeQuota(.blog)
        return result
    }

    // MARK: - Private helpers

    @MainActor
    private func chargeQuota(_ type: AICallType) {
        AIQuotaStore.shared.charge(type)
    }

    private func generate(_ prompt: String) async throws -> String {
        #if DEBUG
        print("[Gemini] Sending prompt (\(prompt.count) chars) to Firebase AI…")
        #endif
        do {
            let response = try await currentModel().generateContent(prompt)
            #if DEBUG
            print("[Gemini] Got response")
            #endif
            guard let text = response.text, !text.isEmpty else { throw AIError.emptyResponse }
            return text
        } catch let aiErr as AIError {
            throw aiErr
        } catch {
            #if DEBUG
            let nsErr = error as NSError
            print("[Gemini] Raw error: \(error)")
            print("[Gemini] NSError domain: \(nsErr.domain), code: \(nsErr.code)")
            print("[Gemini] userInfo keys: \(nsErr.userInfo.keys.joined(separator: ", "))")
            for (k, v) in nsErr.userInfo { print("[Gemini]   \(k): \(v)") }
            #endif
            let mapped = AIError.from(error)
            // On quota exceeded: mark exhausted so counter shows full even after reinstall
            if case .quotaExceeded = mapped {
                let model = AppSettings.GeminiModel(rawValue:
                    UserDefaults.standard.string(forKey: AppSettings.Key.geminiModel)
                    ?? AppSettings.Default.geminiModel) ?? .flashLite
                AIQuotaStore.shared.markExhausted(for: model, type: .summary)
            } else if case .rateLimited = mapped {
                await chargeQuota(.summary)
            }
            throw mapped
        }
    }

    private func generate(_ contents: [ModelContent]) async throws -> String {
        do {
            let response = try await currentModel().generateContent(contents)
            guard let text = response.text, !text.isEmpty else { throw AIError.emptyResponse }
            return text
        } catch let aiErr as AIError {
            throw aiErr
        } catch {
            #if DEBUG
            let nsErr = error as NSError
            print("[Gemini] Raw error (chat): \(error)")
            print("[Gemini] domain: \(nsErr.domain), code: \(nsErr.code)")
            for (k, v) in nsErr.userInfo { print("[Gemini]   \(k): \(v)") }
            #endif
            let mapped = AIError.from(error)
            if case .quotaExceeded = mapped {
                let model = AppSettings.GeminiModel(rawValue:
                    UserDefaults.standard.string(forKey: AppSettings.Key.geminiModel)
                    ?? AppSettings.Default.geminiModel) ?? .flashLite
                AIQuotaStore.shared.markExhausted(for: model, type: .chat)
            } else if case .rateLimited = mapped {
                await chargeQuota(.chat)
            }
            throw mapped
        }
    }
}
