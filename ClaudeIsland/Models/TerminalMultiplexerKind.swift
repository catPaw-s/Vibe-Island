//
//  TerminalMultiplexerKind.swift
//  ClaudeIsland
//
//  Supported terminal multiplexers for interactive Claude sessions.
//

import Foundation

enum TerminalMultiplexerKind: String, Sendable, CaseIterable {
    case tmux
    case cmux

    var displayName: String {
        rawValue.uppercased()
    }

    var commandName: String {
        rawValue
    }
}
