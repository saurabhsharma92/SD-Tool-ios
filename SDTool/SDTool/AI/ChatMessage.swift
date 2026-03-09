//
//  ChatMessage.swift
//  SDTool
//

import Foundation

struct ChatMessage: Identifiable {
    let id        = UUID()
    let role:      ChatRole
    let text:      String
    let timestamp: Date    = Date()
    let error:     AIError? // non-nil for error messages — rendered as AIErrorBubble

    enum ChatRole { case user, assistant }

    // Convenience inits
    static func user(_ text: String)      -> ChatMessage { .init(role: .user,      text: text, error: nil) }
    static func assistant(_ text: String) -> ChatMessage { .init(role: .assistant, text: text, error: nil) }
    static func error(_ err: AIError)     -> ChatMessage { .init(role: .assistant, text: "", error: err) }
}
