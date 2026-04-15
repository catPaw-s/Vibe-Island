//
//  CodexHookInstaller.swift
//  ClaudeIsland
//
//  Installs Codex hooks into ~/.codex/hooks.json.
//

import Foundation

struct CodexHookInstaller {
    private static let supportedEvents: [(name: String, timeout: Int?)] = [
        ("SessionStart", nil),
        ("UserPromptSubmit", nil),
        ("PreToolUse", nil),
        ("PostToolUse", nil),
        ("PermissionRequest", 86400),
        ("Stop", nil),
    ]
    private static let backupFileName = "hooks.json.backup"

    static func install() {
        try? FileManager.default.createDirectory(
            at: CodexPaths.integrationDir,
            withIntermediateDirectories: true
        )

        if let bundled = Bundle.main.url(forResource: "codex-island-state", withExtension: "py") {
            try? FileManager.default.removeItem(at: CodexPaths.hookScript)
            try? FileManager.default.copyItem(at: bundled, to: CodexPaths.hookScript)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: CodexPaths.hookScript.path
            )
        }

        updateHooksFile()
    }

    static func uninstall() {
        try? FileManager.default.removeItem(at: CodexPaths.hookScript)

        guard let data = try? Data(contentsOf: CodexPaths.hooksFile),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = json["hooks"] as? [String: Any] else {
            return
        }

        for (event, value) in hooks {
            guard let entries = value as? [[String: Any]] else { continue }
            let cleaned = entries.compactMap { removingClaudeIslandHooks(from: $0) }
            if cleaned.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = cleaned
            }
        }

        if hooks.isEmpty {
            json.removeValue(forKey: "hooks")
        } else {
            json["hooks"] = hooks
        }

        if let updated = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? updated.write(to: CodexPaths.hooksFile)
        }
    }

    static func isInstalled() -> Bool {
        guard let data = try? Data(contentsOf: CodexPaths.hooksFile),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any] else {
            return false
        }

        for (_, value) in hooks {
            guard let entries = value as? [[String: Any]] else { continue }
            for entry in entries {
                guard let entryHooks = entry["hooks"] as? [[String: Any]] else { continue }
                if entryHooks.contains(where: isClaudeIslandHook) {
                    return true
                }
            }
        }

        return false
    }

    private static func updateHooksFile() {
        var json: [String: Any] = [:]
        var hooks: [String: Any] = [:]

        if FileManager.default.fileExists(atPath: CodexPaths.hooksFile.path) {
            let backupURL = CodexPaths.codexDir.appendingPathComponent(backupFileName)
            if !FileManager.default.fileExists(atPath: backupURL.path) {
                try? FileManager.default.copyItem(at: CodexPaths.hooksFile, to: backupURL)
            }

            if let data = try? Data(contentsOf: CodexPaths.hooksFile),
               let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                json = existing
                hooks = existing["hooks"] as? [String: Any] ?? [:]
            }
        }

        let command = "\(ClaudeHookInstaller.detectPython()) \(CodexPaths.hookScriptShellPath)"
        var cleanedHooks: [String: Any] = [:]
        for (event, value) in hooks {
            guard let entries = value as? [[String: Any]] else {
                cleanedHooks[event] = value
                continue
            }

            let cleaned = entries.compactMap { removingClaudeIslandHooks(from: $0) }
            if !cleaned.isEmpty {
                cleanedHooks[event] = cleaned
            }
        }
        hooks = cleanedHooks

        for event in supportedEvents {
            var hook: [String: Any] = [
                "type": "command",
                "command": command,
            ]
            if let timeout = event.timeout {
                hook["timeout"] = timeout
            }

            let existing = hooks[event.name] as? [[String: Any]] ?? []
            hooks[event.name] = existing + [["hooks": [hook]]]
        }

        json["hooks"] = hooks

        if let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) {
            try? data.write(to: CodexPaths.hooksFile)
        }
    }

    private static func removingClaudeIslandHooks(from entry: [String: Any]) -> [String: Any]? {
        guard var entryHooks = entry["hooks"] as? [[String: Any]] else {
            return entry
        }

        entryHooks.removeAll(where: isClaudeIslandHook)
        guard !entryHooks.isEmpty else { return nil }

        var updatedEntry = entry
        updatedEntry["hooks"] = entryHooks
        return updatedEntry
    }

    private static func isClaudeIslandHook(_ hook: [String: Any]) -> Bool {
        let command = hook["command"] as? String ?? ""
        return command.contains("codex-island-state.py") || command.contains("/.codex/claude-island/")
    }
}
