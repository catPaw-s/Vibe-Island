//
//  CmuxController.swift
//  ClaudeIsland
//
//  High-level cmux operations controller.
//

import Foundation
import os.log

actor CmuxController {
    static let shared = CmuxController()
    nonisolated static let logger = Logger(subsystem: "com.claudeisland", category: "CmuxController")

    private init() {}

    func findTarget(forClaudePid pid: Int) async -> CmuxTarget? {
        await CmuxTargetFinder.shared.findTarget(forClaudePid: pid)
    }

    func findTarget(forWorkingDirectory dir: String) async -> CmuxTarget? {
        await CmuxTargetFinder.shared.findTarget(forWorkingDirectory: dir)
    }

    func findTarget(forTTY tty: String) async -> CmuxTarget? {
        await CmuxTargetFinder.shared.findTarget(forTTY: tty)
    }

    func switchToPane(target: CmuxTarget) async -> Bool {
        guard let cmuxPath = await CmuxPathFinder.shared.getCmuxPath() else {
            Self.logger.error("switchToPane failed: no cmux executable")
            return false
        }

        do {
            Self.logger.debug("switchToPane cmux pane=\(target.paneRef, privacy: .public) workspace=\(target.workspaceRef, privacy: .public)")
            _ = try await ProcessExecutor.shared.run(cmuxPath, arguments: [
                "focus-pane", "--pane", target.paneRef, "--workspace", target.workspaceRef
            ])
            return true
        } catch {
            Self.logger.error("switchToPane failed pane=\(target.paneRef, privacy: .public) workspace=\(target.workspaceRef, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func sendMessage(_ message: String, to target: CmuxTarget) async -> Bool {
        await send(text: message, to: target, pressEnter: true)
    }

    func approveOnce(target: CmuxTarget) async -> Bool {
        await send(text: "1", to: target, pressEnter: true)
    }

    func approveAlways(target: CmuxTarget) async -> Bool {
        await send(text: "2", to: target, pressEnter: true)
    }

    func reject(target: CmuxTarget, message: String? = nil) async -> Bool {
        guard await send(text: "n", to: target, pressEnter: true) else {
            return false
        }

        if let message, !message.isEmpty {
            try? await Task.sleep(for: .milliseconds(100))
            return await send(text: message, to: target, pressEnter: true)
        }

        return true
    }

    private func send(text: String, to target: CmuxTarget, pressEnter: Bool) async -> Bool {
        guard let cmuxPath = await CmuxPathFinder.shared.getCmuxPath() else {
            return false
        }

        var sendArgs = ["send", "--workspace", target.workspaceRef]
        if let surfaceRef = target.surfaceRef {
            sendArgs.append(contentsOf: ["--surface", surfaceRef])
        }
        sendArgs.append(text)

        do {
            _ = try await ProcessExecutor.shared.run(cmuxPath, arguments: sendArgs)
            if pressEnter {
                var keyArgs = ["send-key", "--workspace", target.workspaceRef]
                if let surfaceRef = target.surfaceRef {
                    keyArgs.append(contentsOf: ["--surface", surfaceRef])
                }
                keyArgs.append("Enter")
                _ = try await ProcessExecutor.shared.run(cmuxPath, arguments: keyArgs)
            }
            return true
        } catch {
            Self.logger.error("send failed workspace=\(target.workspaceRef, privacy: .public) surface=\(target.surfaceRef ?? "-", privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
