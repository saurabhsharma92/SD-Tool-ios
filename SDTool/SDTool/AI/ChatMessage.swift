//
//  ChatMessage.swift
//  SDTool
//

import Foundation

struct ChatMessage: Identifiable {
    let id        = UUID()
    let role:      ChatRole
    let text:      String
    let timestamp: Date = Date()

    enum ChatRole { case user, assistant }
}
