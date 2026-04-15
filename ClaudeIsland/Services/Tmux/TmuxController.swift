//
//  TmuxController.swift
//  ClaudeIsland
//
//  High-level tmux operations controller
//

import Foundation
import os.log

/// Controller for tmux operations
actor TmuxController {
    static let shared = TmuxController()
    nonisolated static let logger = Logger(subsystem: "com.claudeisland", category: "TmuxController")

    private init() {}

    func findTmuxTarget(forClaudePid pid: Int) async -> TmuxTarget? {
        await TmuxTargetFinder.shared.findTarget(forClaudePid: pid)
    }

    func findTmuxTarget(forWorkingDirectory dir: String) async -> TmuxTarget? {
        await TmuxTargetFinder.shared.findTarget(forWorkingDirectory: dir)
    }

    func sendMessage(_ message: String, to target: TmuxTarget) async -> Bool {
        await ToolApprovalHandler.shared.sendMessage(message, to: target)
    }

    func approveOnce(target: TmuxTarget) async -> Bool {
        await ToolApprovalHandler.shared.approveOnce(target: target)
    }

    func approveAlways(target: TmuxTarget) async -> Bool {
        await ToolApprovalHandler.shared.approveAlways(target: target)
    }

    func reject(target: TmuxTarget, message: String? = nil) async -> Bool {
        await ToolApprovalHandler.shared.reject(target: target, message: message)
    }

    func switchToPane(target: TmuxTarget) async -> Bool {
        guard let tmuxPath = await TmuxPathFinder.shared.getTmuxPath() else {
            Self.logger.error("switchToPane failed: no tmux executable")
            return false
        }

        do {
            Self.logger.debug("switchToPane tmux target=\(target.targetString, privacy: .public)")
            _ = try await ProcessExecutor.shared.run(tmuxPath, arguments: [
                "select-window", "-t", "\(target.session):\(target.window)"
            ])

            _ = try await ProcessExecutor.shared.run(tmuxPath, arguments: [
                "select-pane", "-t", target.targetString
            ])

            return true
        } catch {
            Self.logger.error("switchToPane failed target=\(target.targetString, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
