//
//  CmuxTarget.swift
//  ClaudeIsland
//
//  Data model for cmux workspace/pane/surface targeting.
//

import Foundation

struct CmuxTarget: Sendable {
    let workspaceRef: String
    let paneRef: String
    let surfaceRef: String?

    nonisolated init(workspaceRef: String, paneRef: String, surfaceRef: String? = nil) {
        self.workspaceRef = workspaceRef
        self.paneRef = paneRef
        self.surfaceRef = surfaceRef
    }
}
