//
//  EditorSource.swift
//  ClaudeIsland
//
//  Supported editor/agent clients that can send session events to the app.
//

import Foundation

enum EditorSource: String, Codable, CaseIterable, Sendable {
    case claude
    case codex

    var displayName: String {
        switch self {
        case .claude:
            return "Claude"
        case .codex:
            return "Codex"
        }
    }
}
