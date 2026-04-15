//
//  CmuxTargetFinder.swift
//  ClaudeIsland
//
//  Finds cmux workspace/pane targets for Claude processes.
//

import Foundation
import os.log

actor CmuxTargetFinder {
    static let shared = CmuxTargetFinder()
    nonisolated static let logger = Logger(subsystem: "com.claudeisland", category: "CmuxTargetFinder")

    private init() {}

    func findTarget(forClaudePid claudePid: Int) async -> CmuxTarget? {
        let tree = ProcessTreeBuilder.shared.buildTree()
        guard let tty = tree[claudePid]?.tty else {
            Self.logger.error("findTarget(forClaudePid:) failed: no tty for pid=\(claudePid, privacy: .public)")
            return nil
        }

        if let target = await findTarget(forTTY: tty) {
            Self.logger.debug("Resolved cmux target for pid=\(claudePid, privacy: .public) via tty=\(tty, privacy: .public)")
            return target
        }

        return nil
    }

    func findTarget(forWorkingDirectory workingDir: String) async -> CmuxTarget? {
        guard let entries = await loadTreeEntries() else { return nil }

        let tree = ProcessTreeBuilder.shared.buildTree()
        for entry in entries {
            guard let tty = entry.tty else { continue }
            for (pid, info) in tree where info.tty == tty {
                guard let cwd = ProcessTreeBuilder.shared.getWorkingDirectory(forPid: pid),
                      cwd == workingDir else { continue }
                return entry.target
            }
        }

        return nil
    }

    func findTarget(forTTY tty: String) async -> CmuxTarget? {
        let normalizedTTY = tty.replacingOccurrences(of: "/dev/", with: "")
        Self.logger.debug("findTarget(forTTY:) tty=\(normalizedTTY, privacy: .public)")

        guard let entries = await loadTreeEntries() else {
            Self.logger.error("findTarget(forTTY:) failed: unable to load cmux tree")
            return nil
        }

        if let match = entries.first(where: { $0.tty == normalizedTTY }) {
            Self.logger.debug("Matched cmux tty=\(normalizedTTY, privacy: .public) workspace=\(match.target.workspaceRef, privacy: .public) pane=\(match.target.paneRef, privacy: .public) surface=\(match.target.surfaceRef ?? "-", privacy: .public)")
            return match.target
        }

        let observedTTYs = entries.compactMap(\.tty).joined(separator: ",")
        Self.logger.error("No cmux target matched tty=\(normalizedTTY, privacy: .public). Observed ttys=[\(observedTTYs, privacy: .public)]")
        return nil
    }

    func isSessionPaneActive(claudePid: Int) async -> Bool {
        guard let target = await findTarget(forClaudePid: claudePid),
              let cmuxPath = await CmuxPathFinder.shared.getCmuxPath(),
              let output = await runCmuxCommand(cmuxPath: cmuxPath, args: ["identify"]),
              let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let focused = json["focused"] as? [String: Any],
              let paneRef = focused["pane_ref"] as? String,
              let workspaceRef = focused["workspace_ref"] as? String else {
            return false
        }

        return paneRef == target.paneRef && workspaceRef == target.workspaceRef
    }

    private func loadTreeEntries() async -> [(target: CmuxTarget, tty: String?)]? {
        guard let cmuxPath = await CmuxPathFinder.shared.getCmuxPath(),
              let output = await runCmuxCommand(cmuxPath: cmuxPath, args: ["tree", "--all"]) else {
            return nil
        }

        return parseTree(output: output)
    }

    private func parseTree(output: String) -> [(target: CmuxTarget, tty: String?)] {
        let lines = output.components(separatedBy: "\n")
        var currentWorkspaceRef: String?
        var currentPaneRef: String?
        var results: [(target: CmuxTarget, tty: String?)] = []

        for line in lines {
            if let workspaceRef = match(in: line, pattern: #"workspace (workspace:\d+)"#) {
                currentWorkspaceRef = workspaceRef
                continue
            }

            if let paneRef = match(in: line, pattern: #"pane (pane:\d+)"#) {
                currentPaneRef = paneRef
                continue
            }

            if let surfaceRef = match(in: line, pattern: #"surface (surface:\d+)"#),
               let workspaceRef = currentWorkspaceRef,
               let paneRef = currentPaneRef {
                let tty = match(in: line, pattern: #"tty=([A-Za-z0-9]+)"#)
                results.append((
                    target: CmuxTarget(workspaceRef: workspaceRef, paneRef: paneRef, surfaceRef: surfaceRef),
                    tty: tty
                ))
            }
        }

        return results
    }

    private func match(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let groupRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[groupRange])
    }

    private func runCmuxCommand(cmuxPath: String, args: [String]) async -> String? {
        do {
            return try await ProcessExecutor.shared.run(cmuxPath, arguments: args)
        } catch {
            return nil
        }
    }
}
