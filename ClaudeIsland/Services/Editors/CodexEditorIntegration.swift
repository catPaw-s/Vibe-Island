//
//  CodexEditorIntegration.swift
//  ClaudeIsland
//
//  Codex-specific hook installation and history parsing adapter.
//

import Foundation

struct CodexEditorIntegration: EditorIntegration {
    let source: EditorSource = .codex

    func installHooks() {
        CodexHookInstaller.install()
    }

    func uninstallHooks() {
        CodexHookInstaller.uninstall()
    }

    func isHooksInstalled() -> Bool {
        CodexHookInstaller.isInstalled()
    }

    func shouldSyncConversation(for event: HookEvent) -> Bool {
        false
    }

    func loadConversation(sessionId: String, cwd: String) async -> ConversationLoadResult {
        await CodexConversationParser.shared.loadConversation(sessionId: sessionId, cwd: cwd)
    }

    func syncConversation(sessionId: String, cwd: String) async -> ConversationSyncResult {
        ConversationSyncResult(
            newMessages: [],
            completedToolIds: [],
            toolResults: [:],
            structuredResults: [:],
            clearDetected: false
        )
    }
}
