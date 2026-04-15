//
//  EditorIntegrationRegistry.swift
//  ClaudeIsland
//
//  Central lookup for all supported editor integrations.
//

import Foundation

enum EditorIntegrationRegistry {
    static let all: [any EditorIntegration] = [
        ClaudeEditorIntegration(),
        CodexEditorIntegration(),
    ]

    static func integration(for source: EditorSource) -> any EditorIntegration {
        all.first(where: { $0.source == source }) ?? ClaudeEditorIntegration()
    }

    static func installAllHooks() {
        all.forEach { $0.installHooks() }
    }

    static func uninstallAllHooks() {
        all.forEach { $0.uninstallHooks() }
    }

    static func areAllHooksInstalled() -> Bool {
        all.allSatisfy { $0.isHooksInstalled() }
    }
}
