//
//  AnalyticsManager.swift
//  ClaudeIsland
//
//  Centralizes analytics initialization so Mixpanel is ready before any event tracking.
//

import Foundation
import Mixpanel

enum AnalyticsManager {
    private static let token = "49814c1436104ed108f3fc4735228496"
    private static var hasInitialized = false
    private static let lock = NSLock()

    static func ensureInitialized() {
        lock.lock()
        defer { lock.unlock() }

        guard !hasInitialized else { return }
        Mixpanel.initialize(token: token)
        hasInitialized = true
    }
}
