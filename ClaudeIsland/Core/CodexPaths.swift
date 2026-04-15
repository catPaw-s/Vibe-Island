//
//  CodexPaths.swift
//  ClaudeIsland
//
//  Path helpers for Codex config and hook files.
//

import Foundation

enum CodexPaths {
    static var codexDir: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
    }

    static var hooksFile: URL {
        codexDir.appendingPathComponent("hooks.json")
    }

    static var integrationDir: URL {
        codexDir.appendingPathComponent("claude-island")
    }

    static var hookScript: URL {
        integrationDir.appendingPathComponent("codex-island-state.py")
    }

    static var hookScriptShellPath: String {
        shellQuote(hookScript.path)
    }

    private static func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
