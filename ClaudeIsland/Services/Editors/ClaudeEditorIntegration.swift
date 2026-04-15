//
//  ClaudeEditorIntegration.swift
//  ClaudeIsland
//
//  Claude-specific hook installation and JSONL parsing adapter.
//

import Foundation

struct ClaudeEditorIntegration: EditorIntegration {
    let source: EditorSource = .claude

    func installHooks() {
        ClaudeHookInstaller.install()
    }

    func uninstallHooks() {
        ClaudeHookInstaller.uninstall()
    }

    func isHooksInstalled() -> Bool {
        ClaudeHookInstaller.isInstalled()
    }

    func shouldSyncConversation(for event: HookEvent) -> Bool {
        switch event.event {
        case "UserPromptSubmit", "PreToolUse", "PostToolUse", "Stop":
            return true
        default:
            return false
        }
    }

    func loadConversation(sessionId: String, cwd: String) async -> ConversationLoadResult {
        let messages = await ConversationParser.shared.parseFullConversation(
            sessionId: sessionId,
            cwd: cwd
        )
        let completedToolIds = await ConversationParser.shared.completedToolIds(for: sessionId)
        let toolResults = await ConversationParser.shared.toolResults(for: sessionId)
        let structuredResults = await ConversationParser.shared.structuredResults(for: sessionId)
        let conversationInfo = await ConversationParser.shared.parse(
            sessionId: sessionId,
            cwd: cwd
        )

        return ConversationLoadResult(
            messages: messages,
            completedToolIds: completedToolIds,
            toolResults: toolResults,
            structuredResults: structuredResults,
            conversationInfo: conversationInfo
        )
    }

    func syncConversation(sessionId: String, cwd: String) async -> ConversationSyncResult {
        let result = await ConversationParser.shared.parseIncremental(
            sessionId: sessionId,
            cwd: cwd
        )

        return ConversationSyncResult(
            newMessages: result.newMessages,
            completedToolIds: result.completedToolIds,
            toolResults: result.toolResults,
            structuredResults: result.structuredResults,
            clearDetected: result.clearDetected
        )
    }
}
