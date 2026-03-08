//
//  GeminiService.swift
//  SDTool
//

import FirebaseAI

actor GeminiService {
    static let shared = GeminiService()

    private let model: GenerativeModel

    private init() {
        let ai = FirebaseAI.firebaseAI(backend: .googleAI())
        // gemini-2.5-flash-lite: free tier, fast, good for summarisation & chat
        model = ai.generativeModel(modelName: "gemini-2.5-flash-lite")
    }

    // MARK: - Article: summarise for context (used as chat context, not shown to user)
    // Returns a condensed ~400 word summary — cached so chat opens instantly on reuse.

    func summarizeForContext(_ markdown: String) async throws -> String {
        let prompt = """
        Summarize this technical article in 3–5 concise paragraphs (under 400 words).
        Preserve all key concepts, terminology, numbers, and architectural decisions.
        Output plain text only — no markdown, no bullet points.

        ARTICLE:
        \(String(markdown.prefix(14_000)))
        """
        return try await generate(prompt)
    }

    // MARK: - Article: summarise for reading (shown to user, formatted markdown)

    func summarizeForReading(_ markdown: String) async throws -> String {
        let prompt = """
        Write a clear, well-structured summary of this technical article for an engineer.
        Start with one sentence stating what the article covers.
        Then list the most important points as bullet points (use • prefix).
        Finish with a one-line "Key takeaway:".
        Use **bold** for important terms. Keep it under 300 words.

        ARTICLE:
        \(String(markdown.prefix(14_000)))
        """
        return try await generate(prompt)
    }

    // MARK: - Article: ELI5

    func explainSimply(_ markdown: String, topic: String) async throws -> String {
        let prompt = """
        Explain the main ideas of this technical article to someone with no tech background.
        Use simple words, short sentences, and one everyday analogy.
        Avoid all jargon. Imagine explaining to a curious 12-year-old.
        Structure: one opening sentence, then 3–4 short paragraphs. Under 250 words.

        TOPIC: \(topic)
        ARTICLE:
        \(String(markdown.prefix(14_000)))
        """
        return try await generate(prompt)
    }

    // MARK: - Article chat (multi-turn)

    func chat(
        history: [ChatMessage],
        newMessage: String,
        contextSummary: String
    ) async throws -> String {
        var contents: [ModelContent] = []

        // System context injected as the first exchange
        let systemContext = """
        You are a helpful technical mentor. The user is studying the following article.
        Answer questions accurately and concisely. If something is not covered in the article, say so.
        Do not make things up. Use markdown formatting in your answers (bold, code blocks, bullet points).

        ARTICLE SUMMARY:
        \(contextSummary)
        """
        contents.append(ModelContent(role: "user",  parts: [TextPart(systemContext)]))
        contents.append(ModelContent(role: "model", parts: [TextPart("Got it — I've read the article summary and I'm ready to help. What would you like to know?")]))

        // Append conversation history (cap at last 10 exchanges to avoid token bloat)
        let recentHistory = history.suffix(20)
        for msg in recentHistory {
            contents.append(ModelContent(
                role: msg.role == .user ? "user" : "model",
                parts: [TextPart(msg.text)]
            ))
        }

        // Append new user message
        contents.append(ModelContent(role: "user", parts: [TextPart(newMessage)]))

        return try await generate(contents)
    }

    // MARK: - Blog: summarise post

    func summarizeBlogPost(title: String, content: String) async throws -> String {
        print("[Gemini] summarizeBlogPost called — title: \(title), content: \(content.count) chars")
        let prompt = """
        Summarize this blog post for a software engineer.
        Start with one sentence stating the main point.
        Then list 3–5 key insights as bullet points (use • prefix).
        Use **bold** for important terms. Under 200 words.

        TITLE: \(title)
        CONTENT:
        \(String(content.prefix(10_000)))
        """
        return try await generate(prompt)
    }

    // MARK: - Blog: ELI5

    func explainBlogPost(title: String, content: String) async throws -> String {
        print("[Gemini] explainBlogPost called — title: \(title), content: \(content.count) chars")
        let prompt = """
        Explain the key idea of this blog post to someone who doesn't work in tech.
        Use simple language, short sentences, and one everyday analogy.
        No jargon. Engaging and friendly tone. Under 200 words.

        TITLE: \(title)
        CONTENT:
        \(String(content.prefix(10_000)))
        """
        return try await generate(prompt)
    }

    // MARK: - Private helpers

    private func generate(_ prompt: String) async throws -> String {
        print("[Gemini] Sending prompt (\(prompt.count) chars) to Firebase AI…")
        do {
            let response = try await model.generateContent(prompt)
            print("[Gemini] Got response")
            guard let text = response.text, !text.isEmpty else { throw AIError.emptyResponse }
            return text
        } catch let aiErr as AIError {
            throw aiErr
        } catch {
            throw AIError.from(error)
        }
    }

    private func generate(_ contents: [ModelContent]) async throws -> String {
        do {
            let response = try await model.generateContent(contents)
            guard let text = response.text, !text.isEmpty else { throw AIError.emptyResponse }
            return text
        } catch let aiErr as AIError {
            throw aiErr
        } catch {
            throw AIError.from(error)
        }
    }
}
