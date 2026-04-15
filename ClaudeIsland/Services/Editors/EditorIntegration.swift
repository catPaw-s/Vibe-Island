//
//  EditorIntegration.swift
//  ClaudeIsland
//
//  Extensible integration contract for editor-specific hooks and history parsing.
//

import Foundation

struct ConversationLoadResult {
    let messages: [ChatMessage]
    let completedToolIds: Set<String>
    let toolResults: [String: ConversationParser.ToolResult]
    let structuredResults: [String: ToolResultData]
    let conversationInfo: ConversationInfo
}

struct ConversationSyncResult {
    let newMessages: [ChatMessage]
    let completedToolIds: Set<String>
    let toolResults: [String: ConversationParser.ToolResult]
    let structuredResults: [String: ToolResultData]
    let clearDetected: Bool
}

protocol EditorIntegration {
    var source: EditorSource { get }

    func installHooks()
    func uninstallHooks()
    func isHooksInstalled() -> Bool
    func shouldSyncConversation(for event: HookEvent) -> Bool
    func loadConversation(sessionId: String, cwd: String) async -> ConversationLoadResult
    func syncConversation(sessionId: String, cwd: String) async -> ConversationSyncResult
}
