//
//  YabaiController.swift
//  ClaudeIsland
//
//  High-level yabai window management controller
//

import AppKit
import Foundation
import os.log

/// Controller for yabai window management
actor YabaiController {
    static let shared = YabaiController()
    nonisolated static let logger = Logger(subsystem: "com.claudeisland", category: "YabaiController")

    private init() {}

    // MARK: - Public API

    func focusWindow(forTTY tty: String, preferred kind: TerminalMultiplexerKind? = nil) async -> Bool {
        let normalizedTTY = tty.replacingOccurrences(of: "/dev/", with: "")
        Self.logger.debug("focusWindow(forTTY:) tty=\(normalizedTTY, privacy: .public) preferred=\(kind?.rawValue ?? "nil", privacy: .public)")

        guard await WindowFinder.shared.isYabaiAvailable() else {
            Self.logger.error("focusWindow(forTTY:) yabai unavailable, falling back tty=\(normalizedTTY, privacy: .public)")
            return await focusWithoutYabai(forTTY: normalizedTTY, preferred: kind)
        }

        let windows = await WindowFinder.shared.getAllWindows()
        switch kind {
        case .cmux:
            if let target = await CmuxTargetFinder.shared.findTarget(forTTY: normalizedTTY) {
                Self.logger.debug("focusWindow(forTTY:) resolved cmux workspace=\(target.workspaceRef, privacy: .public) pane=\(target.paneRef, privacy: .public)")
                _ = await CmuxController.shared.switchToPane(target: target)
                if let terminalPid = findCmuxTerminalPid(windows: windows) {
                    return await WindowFocuser.shared.focusTmuxWindow(terminalPid: terminalPid, windows: windows)
                }
            }
        case .tmux, nil:
            if let target = await TmuxTargetFinder.shared.findTarget(forTTY: normalizedTTY) {
                Self.logger.debug("focusWindow(forTTY:) resolved tmux target=\(target.targetString, privacy: .public)")
                _ = await TmuxController.shared.switchToPane(target: target)
                if let terminalPid = await findTmuxClientTerminal(forSession: target.session, tree: ProcessTreeBuilder.shared.buildTree(), windows: windows) {
                    return await WindowFocuser.shared.focusTmuxWindow(terminalPid: terminalPid, windows: windows)
                }
            }
        }

        Self.logger.error("focusWindow(forTTY:) failed: no target tty=\(normalizedTTY, privacy: .public)")
        return false
    }

    /// Focus the terminal window for a given Claude PID in a supported multiplexer
    func focusWindow(forClaudePid claudePid: Int) async -> Bool {
        let tree = ProcessTreeBuilder.shared.buildTree()
        let multiplexer = ProcessTreeBuilder.shared.terminalMultiplexer(pid: claudePid, tree: tree)
        let tty = tree[claudePid]?.tty ?? "nil"
        Self.logger.debug("focusWindow(forClaudePid:) pid=\(claudePid, privacy: .public) tty=\(tty, privacy: .public) multiplexer=\(multiplexer?.rawValue ?? "nil", privacy: .public)")

        guard await WindowFinder.shared.isYabaiAvailable() else {
            Self.logger.error("focusWindow(forClaudePid:) yabai unavailable, falling back pid=\(claudePid, privacy: .public)")
            return await focusWithoutYabai(forClaudePid: claudePid, preferred: multiplexer)
        }

        let windows = await WindowFinder.shared.getAllWindows()
        switch multiplexer {
        case .cmux:
            return await focusCmuxInstance(claudePid: claudePid, windows: windows)
        case .tmux, nil:
            return await focusTmuxInstance(claudePid: claudePid, tree: tree, windows: windows)
        }
    }

    /// Focus the terminal window for a given working directory in a supported multiplexer
    func focusWindow(forWorkingDirectory workingDirectory: String) async -> Bool {
        guard await WindowFinder.shared.isYabaiAvailable() else {
            Self.logger.error("focusWindow(forWorkingDirectory:) yabai unavailable, falling back cwd=\(workingDirectory, privacy: .public)")
            return await focusWithoutYabai(forWorkingDirectory: workingDirectory)
        }

        Self.logger.debug("focusWindow(forWorkingDirectory:) cwd=\(workingDirectory, privacy: .public)")

        let windows = await WindowFinder.shared.getAllWindows()
        if let target = await CmuxController.shared.findTarget(forWorkingDirectory: workingDirectory) {
            Self.logger.debug("focusWindow(forWorkingDirectory:) resolved cmux workspace=\(target.workspaceRef, privacy: .public) pane=\(target.paneRef, privacy: .public)")
            _ = await CmuxController.shared.switchToPane(target: target)
            if let terminalPid = findCmuxTerminalPid(windows: windows) {
                return await WindowFocuser.shared.focusTmuxWindow(terminalPid: terminalPid, windows: windows)
            }
            return activateCmuxApp()
        }

        return await focusWindow(forWorkingDir: workingDirectory)
    }

    // MARK: - Private Implementation

    private func focusTmuxInstance(claudePid: Int, tree: [Int: ProcessInfo], windows: [YabaiWindow]) async -> Bool {
        guard let target = await TmuxController.shared.findTmuxTarget(forClaudePid: claudePid) else {
            Self.logger.error("focusTmuxInstance failed: no target for pid=\(claudePid, privacy: .public)")
            return false
        }

        Self.logger.debug("focusTmuxInstance resolved pid=\(claudePid, privacy: .public) target=\(target.targetString, privacy: .public)")

        _ = await TmuxController.shared.switchToPane(target: target)

        if let terminalPid = await findTmuxClientTerminal(forSession: target.session, tree: tree, windows: windows) {
            Self.logger.debug("focusTmuxInstance focusing terminalPid=\(terminalPid, privacy: .public)")
            return await WindowFocuser.shared.focusTmuxWindow(terminalPid: terminalPid, windows: windows)
        }

        Self.logger.error("focusTmuxInstance failed: no terminalPid")
        return false
    }

    private func focusCmuxInstance(claudePid: Int, windows: [YabaiWindow]) async -> Bool {
        guard let target = await CmuxController.shared.findTarget(forClaudePid: claudePid) else {
            Self.logger.error("focusCmuxInstance failed: no target for pid=\(claudePid, privacy: .public)")
            return false
        }

        Self.logger.debug("focusCmuxInstance resolved pid=\(claudePid, privacy: .public) workspace=\(target.workspaceRef, privacy: .public) pane=\(target.paneRef, privacy: .public)")
        _ = await CmuxController.shared.switchToPane(target: target)

        if let terminalPid = findCmuxTerminalPid(windows: windows) {
            return await WindowFocuser.shared.focusTmuxWindow(terminalPid: terminalPid, windows: windows)
        }

        Self.logger.error("focusCmuxInstance failed: no cmux terminal pid")
        return false
    }

    private func focusWindow(forWorkingDir workingDir: String) async -> Bool {
        let windows = await WindowFinder.shared.getAllWindows()
        let tree = ProcessTreeBuilder.shared.buildTree()
        Self.logger.debug("focusWindow(forWorkingDir:) scanning cwd=\(workingDir, privacy: .public)")

        return await focusTmuxPane(forWorkingDir: workingDir, tree: tree, windows: windows)
    }

    // MARK: - Multiplexer Helpers

    private func findTmuxClientTerminal(forSession session: String, tree: [Int: ProcessInfo], windows: [YabaiWindow]) async -> Int? {
        guard let tmuxPath = await TmuxPathFinder.shared.getTmuxPath() else { return nil }

        do {
            // Get clients attached to this specific session
            let output = try await ProcessExecutor.shared.run(tmuxPath, arguments: [
                "list-clients", "-t", session, "-F", "#{client_pid}"
            ])

            let clientPids = output.components(separatedBy: "\n")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }

            let windowPids = Set(windows.map { $0.pid })

            for clientPid in clientPids {
                var currentPid = clientPid
                while currentPid > 1 {
                    guard let info = tree[currentPid] else { break }
                    if isTerminalProcess(info.command) && windowPids.contains(currentPid) {
                        return currentPid
                    }
                    currentPid = info.ppid
                }
            }
        } catch {
            return nil
        }

        return nil
    }

    private nonisolated func findCmuxTerminalPid(windows: [YabaiWindow]) -> Int? {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.cmuxterm.app")
        let runningPids = Set(runningApps.map { Int($0.processIdentifier) })
        return windows.first(where: { runningPids.contains($0.pid) })?.pid ?? runningPids.first
    }

    private func focusWithoutYabai(forClaudePid claudePid: Int, preferred kind: TerminalMultiplexerKind?) async -> Bool {
        switch kind {
        case .cmux:
            guard let target = await CmuxController.shared.findTarget(forClaudePid: claudePid) else {
                Self.logger.error("focusWithoutYabai(forClaudePid:) failed: no cmux target pid=\(claudePid, privacy: .public)")
                return false
            }
            Self.logger.debug("focusWithoutYabai(forClaudePid:) resolved cmux workspace=\(target.workspaceRef, privacy: .public) pane=\(target.paneRef, privacy: .public)")
            let switched = await CmuxController.shared.switchToPane(target: target)
            let activated = activateCmuxApp()
            return switched || activated
        case .tmux, nil:
            guard let target = await TmuxController.shared.findTmuxTarget(forClaudePid: claudePid) else {
                Self.logger.error("focusWithoutYabai(forClaudePid:) failed: no tmux target pid=\(claudePid, privacy: .public)")
                return false
            }
            Self.logger.debug("focusWithoutYabai(forClaudePid:) resolved tmux target=\(target.targetString, privacy: .public)")
            return await TmuxController.shared.switchToPane(target: target)
        }
    }

    private func focusWithoutYabai(forWorkingDirectory workingDirectory: String) async -> Bool {
        if let target = await CmuxController.shared.findTarget(forWorkingDirectory: workingDirectory) {
            Self.logger.debug("focusWithoutYabai(forWorkingDirectory:) resolved cmux workspace=\(target.workspaceRef, privacy: .public) pane=\(target.paneRef, privacy: .public)")
            let switched = await CmuxController.shared.switchToPane(target: target)
            let activated = activateCmuxApp()
            return switched || activated
        }

        guard let target = await TmuxController.shared.findTmuxTarget(forWorkingDirectory: workingDirectory) else {
            Self.logger.error("focusWithoutYabai(forWorkingDirectory:) failed: no target cwd=\(workingDirectory, privacy: .public)")
            return false
        }

        Self.logger.debug("focusWithoutYabai(forWorkingDirectory:) resolved tmux target=\(target.targetString, privacy: .public)")
        return await TmuxController.shared.switchToPane(target: target)
    }

    private func focusWithoutYabai(forTTY tty: String, preferred kind: TerminalMultiplexerKind?) async -> Bool {
        switch kind {
        case .cmux:
            guard let target = await CmuxTargetFinder.shared.findTarget(forTTY: tty) else {
                Self.logger.error("focusWithoutYabai(forTTY:) failed: no cmux target tty=\(tty, privacy: .public)")
                return false
            }
            Self.logger.debug("focusWithoutYabai(forTTY:) resolved cmux workspace=\(target.workspaceRef, privacy: .public) pane=\(target.paneRef, privacy: .public)")
            let switched = await CmuxController.shared.switchToPane(target: target)
            let activated = activateCmuxApp()
            return switched || activated
        case .tmux, nil:
            guard let target = await TmuxTargetFinder.shared.findTarget(forTTY: tty) else {
                Self.logger.error("focusWithoutYabai(forTTY:) failed: no tmux target tty=\(tty, privacy: .public)")
                return false
            }
            Self.logger.debug("focusWithoutYabai(forTTY:) resolved tmux target=\(target.targetString, privacy: .public)")
            return await TmuxController.shared.switchToPane(target: target)
        }
    }

    private nonisolated func activateCmuxApp() -> Bool {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.cmuxterm.app").first else {
            return false
        }

        return app.activate(options: [.activateIgnoringOtherApps])
    }

    /// Check if command is a terminal (nonisolated helper to avoid MainActor access)
    private nonisolated func isTerminalProcess(_ command: String) -> Bool {
        let terminalCommands = ["Terminal", "iTerm", "iTerm2", "Alacritty", "kitty", "WezTerm", "wezterm-gui", "Hyper"]
        return terminalCommands.contains { command.contains($0) }
    }

    private func focusTmuxPane(forWorkingDir workingDir: String, tree: [Int: ProcessInfo], windows: [YabaiWindow]) async -> Bool {
        guard let target = await TmuxController.shared.findTmuxTarget(forWorkingDirectory: workingDir),
              let tmuxPath = await TmuxPathFinder.shared.getTmuxPath() else {
            Self.logger.error("focusTmuxPane failed: no target/path for cwd=\(workingDir, privacy: .public)")
            return false
        }

        Self.logger.debug("focusTmuxPane resolved cwd=\(workingDir, privacy: .public) target=\(target.targetString, privacy: .public)")

        do {
            let panesOutput = try await ProcessExecutor.shared.run(tmuxPath, arguments: [
                "list-panes", "-a", "-F", "#{session_name}:#{window_index}.#{pane_index}|#{pane_pid}"
            ])

            let panes = panesOutput.components(separatedBy: "\n").filter { !$0.isEmpty }

            for pane in panes {
                let parts = pane.components(separatedBy: "|")
                guard parts.count >= 2,
                      let panePid = Int(parts[1]) else { continue }

                let targetString = parts[0]

                // Check if this pane has a Claude child with matching cwd
                for (pid, info) in tree {
                    let isChild = ProcessTreeBuilder.shared.isDescendant(targetPid: pid, ofAncestor: panePid, tree: tree)
                    let isClaude = info.command.lowercased().contains("claude")

                    guard isChild, isClaude else { continue }

                    guard let cwd = ProcessTreeBuilder.shared.getWorkingDirectory(forPid: pid),
                          cwd == workingDir else { continue }

                    // Found matching pane - switch to it
                    if let paneTarget = TmuxTarget(from: targetString) {
                        _ = await TmuxController.shared.switchToPane(target: paneTarget)

                        if let terminalPid = await findTmuxClientTerminal(forSession: paneTarget.session, tree: tree, windows: windows) {
                            return await WindowFocuser.shared.focusTmuxWindow(terminalPid: terminalPid, windows: windows)
                        }
                    }
                    return true
                }
            }
        } catch {
            return false
        }

        return false
    }
}
