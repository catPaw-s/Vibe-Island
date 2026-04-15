//
//  ChatMessage.swift
//  ClaudeIsland
//
//  Models for conversation messages parsed from JSONL
//

import Foundation
import CryptoKit

/// Produces a stable hex hash string that is consistent across app launches.
/// Swift's hashValue is randomized per process, making it unsuitable for identifiers.
enum StableHash {
    static func hash(_ string: Substring) -> String {
        let data = Data(string.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.prefix(8).joined()
    }
}

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let role: ChatRole
    let timestamp: Date
    let content: [MessageBlock]

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }

    /// Plain text content combined
    var textContent: String {
        content.compactMap { block in
            if case .text(let text) = block {
                return text
            }
            return nil
        }.joined(separator: "\n")
    }
}

enum ChatRole: String, Equatable {
    case user
    case assistant
    case system
}

enum MessageBlock: Equatable, Identifiable {
    case text(String)
    case toolUse(ToolUseBlock)
    case thinking(String)
    case image(ImageBlock)
    case interrupted

    var id: String {
        switch self {
        case .text(let text):
            return "text-\(StableHash.hash(text.prefix(100)))"
        case .toolUse(let block):
            return "tool-\(block.id)"
        case .thinking(let text):
            return "thinking-\(StableHash.hash(text.prefix(100)))"
        case .image(let block):
            return "image-\(block.id)"
        case .interrupted:
            return "interrupted"
        }
    }

    /// Type prefix for generating stable IDs
    nonisolated var typePrefix: String {
        switch self {
        case .text: return "text"
        case .toolUse: return "tool"
        case .thinking: return "thinking"
        case .image: return "image"
        case .interrupted: return "interrupted"
        }
    }
}

/// Represents an inline image attached to a message — base64-encoded with a
/// media type (e.g. "image/png"). Claude Code stores these both as top-level
/// user message blocks and nested inside tool_result content arrays.
struct ImageBlock: Equatable {
    let mediaType: String
    let base64Data: String?
    let filePath: String?

    /// Stable identifier based on the data contents so SwiftUI doesn't
    /// re-render images unnecessarily across parses.
    var id: String {
        if let base64Data, !base64Data.isEmpty {
            return StableHash.hash(base64Data.prefix(200))
        }
        if let filePath, !filePath.isEmpty {
            return StableHash.hash(Substring(filePath))
        }
        return StableHash.hash(Substring(mediaType))
    }
}

struct ToolUseBlock: Equatable {
    let id: String
    let name: String
    let input: [String: String]

    /// Short preview of the tool input
    var preview: String {
        if let filePath = input["file_path"] ?? input["path"] {
            return filePath
        }
        if let command = input["command"] {
            let firstLine = command.components(separatedBy: "\n").first ?? command
            return String(firstLine.prefix(50))
        }
        if let pattern = input["pattern"] {
            return pattern
        }
        return input.values.first.map { String($0.prefix(50)) } ?? ""
    }
}
