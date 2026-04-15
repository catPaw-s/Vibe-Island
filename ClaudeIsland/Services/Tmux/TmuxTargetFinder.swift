//
//  TmuxTargetFinder.swift
//  ClaudeIsland
//
//  Finds tmux targets for Claude processes
//

import Foundation
import os.log

/// Finds tmux session/window/pane targets for Claude processes
actor TmuxTargetFinder {
    static let shared = TmuxTargetFinder()
    nonisolated static let logger = Logger(subsystem: "com.claudeisland", category: "TargetFinder")

    private init() {}

    /// Find the tmux target for a given Claude PID
    func findTarget(forClaudePid claudePid: Int) async -> TmuxTarget? {
        guard let tmuxPath = await TmuxPathFinder.shared.getTmuxPath() else { return nil }
        return await findTarget(forClaudePid: claudePid, executablePath: tmuxPath)
    }

    /// Find the tmux target for a given working directory
    func findTarget(forWorkingDirectory workingDir: String) async -> TmuxTarget? {
        guard let tmuxPath = await TmuxPathFinder.shared.getTmuxPath() else { return nil }
        return await findTarget(forWorkingDirectory: workingDir, executablePath: tmuxPath)
    }

    func findTarget(forTTY tty: String) async -> TmuxTarget? {
        let normalizedTTY = tty.replacingOccurrences(of: "/dev/", with: "")
        Self.logger.debug("findTarget(forTTY:) tty=\(normalizedTTY, privacy: .public)")
        guard let tmuxPath = await TmuxPathFinder.shared.getTmuxPath(),
              let output = await runTmuxCommand(tmuxPath: tmuxPath, args: [
                "list-panes", "-a", "-F", "#{session_name}:#{window_index}.#{pane_index} #{pane_tty}"
              ]) else {
            return nil
        }

        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let targetString = String(parts[0])
            let paneTTY = String(parts[1]).replacingOccurrences(of: "/dev/", with: "")
            if paneTTY == normalizedTTY {
                Self.logger.debug("Matched tmux tty=\(normalizedTTY, privacy: .public) target=\(targetString, privacy: .public)")
                return TmuxTarget(from: targetString)
            }
        }

        Self.logger.error("No tmux target matched tty=\(normalizedTTY, privacy: .public)")
        return nil
    }

    /// Check if a session's tmux pane is currently the active pane
    func isSessionPaneActive(claudePid: Int) async -> Bool {
        guard let sessionTarget = await findTarget(forClaudePid: claudePid),
              let tmuxPath = await TmuxPathFinder.shared.getTmuxPath() else {
            return false
        }

        guard let output = await runTmuxCommand(tmuxPath: tmuxPath, args: [
            "display-message", "-p", "#{session_name}:#{window_index}.#{pane_index}"
        ]) else {
            return false
        }

        let activeTarget = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return sessionTarget.targetString == activeTarget
    }

    private func findTarget(forClaudePid claudePid: Int, executablePath: String) async -> TmuxTarget? {
        guard let output = await runTmuxCommand(tmuxPath: executablePath, args: [
            "list-panes", "-a", "-F", "#{session_name}:#{window_index}.#{pane_index} #{pane_pid}"
        ]) else {
            return nil
        }
        let tree = ProcessTreeBuilder.shared.buildTree()

        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1)
            guard parts.count == 2,
                  let panePid = Int(parts[1]) else { continue }

            let targetString = String(parts[0])

            if ProcessTreeBuilder.shared.isDescendant(targetPid: claudePid, ofAncestor: panePid, tree: tree) {
                return TmuxTarget(from: targetString)
            }
        }

        return nil
    }

    private func findTarget(forWorkingDirectory workingDir: String, executablePath: String) async -> TmuxTarget? {
        guard let output = await runTmuxCommand(tmuxPath: executablePath, args: [
            "list-panes", "-a", "-F", "#{session_name}:#{window_index}.#{pane_index} #{pane_current_path}"
        ]) else {
            return nil
        }

        for line in output.components(separatedBy: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let targetString = String(parts[0])
            let panePath = String(parts[1])

            if panePath == workingDir {
                return TmuxTarget(from: targetString)
            }
        }

        return nil
    }

    // MARK: - Private Methods

    private func runTmuxCommand(tmuxPath: String, args: [String]) async -> String? {
        do {
            return try await ProcessExecutor.shared.run(tmuxPath, arguments: args)
        } catch {
            return nil
        }
    }
}
