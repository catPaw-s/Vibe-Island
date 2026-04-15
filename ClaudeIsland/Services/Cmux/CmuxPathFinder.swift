//
//  CmuxPathFinder.swift
//  ClaudeIsland
//
//  Finds cmux executable path.
//

import Foundation

actor CmuxPathFinder {
    static let shared = CmuxPathFinder()

    private var cachedPath: String?

    private init() {}

    func getCmuxPath() -> String? {
        if let cachedPath {
            return cachedPath
        }

        let candidates = [
            "/Applications/cmux.app/Contents/Resources/bin/cmux",
            "/opt/homebrew/bin/cmux",
            "/usr/local/bin/cmux",
            "/usr/bin/cmux",
            "/bin/cmux"
        ]

        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            cachedPath = path
            return path
        }

        return nil
    }
}
