//
//  CodexConversationParser.swift
//  ClaudeIsland
//
//  Minimal Codex session parser used by the editor integration layer.
//

import Foundation

actor CodexConversationParser {
    static let shared = CodexConversationParser()

    private var pathCache: [String: String] = [:]

    func loadConversation(sessionId: String, cwd: String) -> ConversationLoadResult {
        guard let filePath = sessionFilePath(for: sessionId) else {
            return ConversationLoadResult(
                messages: [],
                completedToolIds: [],
                toolResults: [:],
                structuredResults: [:],
                conversationInfo: ConversationInfo(
                    summary: nil,
                    lastMessage: nil,
                    lastMessageRole: nil,
                    lastToolName: nil,
                    firstUserMessage: nil,
                    lastUserMessageDate: nil
                )
            )
        }

        guard let data = FileManager.default.contents(atPath: filePath),
              let content = String(data: data, encoding: .utf8) else {
            return ConversationLoadResult(
                messages: [],
                completedToolIds: [],
                toolResults: [:],
                structuredResults: [:],
                conversationInfo: ConversationInfo(
                    summary: nil,
                    lastMessage: nil,
                    lastMessageRole: nil,
                    lastToolName: nil,
                    firstUserMessage: nil,
                    lastUserMessageDate: nil
                )
            )
        }

        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        var messages: [ChatMessage] = []
        var completedToolIds = Set<String>()
        var toolResults: [String: ConversationParser.ToolResult] = [:]
        var threadName: String?

        for (index, line) in lines.enumerated() {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let type = json["type"] as? String else {
                continue
            }

            switch type {
            case "session_meta":
                if let payload = json["payload"] as? [String: Any] {
                    threadName = payload["thread_name"] as? String
                }
            case "event_msg":
                guard let payload = json["payload"] as? [String: Any],
                      let payloadType = payload["type"] as? String else {
                    continue
                }

                if payloadType == "user_message",
                   let message = parseUserMessageEvent(payload: payload, fallbackIndex: index, timestamp: json["timestamp"] as? String) {
                    appendMessage(message, to: &messages)
                }
            case "response_item":
                guard let payload = json["payload"] as? [String: Any],
                      let payloadType = payload["type"] as? String else {
                    continue
                }

                if payloadType == "message",
                   let message = parseMessagePayload(payload: payload, fallbackIndex: index, timestamp: json["timestamp"] as? String) {
                    appendMessage(message, to: &messages)
                } else if payloadType == "function_call",
                          let toolCall = parseFunctionCallPayload(payload: payload, fallbackIndex: index, timestamp: json["timestamp"] as? String) {
                    appendMessage(toolCall, to: &messages)
                } else if payloadType == "function_call_output",
                          let callId = payload["call_id"] as? String {
                    completedToolIds.insert(callId)
                    toolResults[callId] = ConversationParser.ToolResult(
                        content: payload["output"] as? String,
                        stdout: nil,
                        stderr: nil,
                        isError: false
                    )
                }
            default:
                continue
            }
        }

        let firstUserMessage = messages.first(where: { $0.role == .user })?.textContent
        let lastTextMessage = messages.last(where: {
            $0.role == .assistant || $0.role == .user
        })
        let lastToolMessage = messages.last(where: {
            $0.content.contains {
                if case .toolUse = $0 { return true }
                return false
            }
        })

        let lastUserMessageDate = messages.last(where: { $0.role == .user })?.timestamp
        let lastToolName = lastToolMessage?.content.compactMap { block -> String? in
            if case .toolUse(let tool) = block {
                return tool.name
            }
            return nil
        }.last

        let lastMessageRole: String?
        if lastToolMessage?.id == messages.last?.id, lastToolName != nil {
            lastMessageRole = "tool"
        } else {
            lastMessageRole = lastTextMessage?.role.rawValue
        }

        let lastMessage = lastToolName != nil && lastToolMessage?.id == messages.last?.id
            ? lastToolName
            : lastTextMessage?.textContent

        let conversationInfo = ConversationInfo(
            summary: truncate(threadName),
            lastMessage: truncate(lastMessage),
            lastMessageRole: lastMessageRole,
            lastToolName: lastToolName,
            firstUserMessage: truncate(firstUserMessage, maxLength: 50),
            lastUserMessageDate: lastUserMessageDate
        )

        return ConversationLoadResult(
            messages: messages,
            completedToolIds: completedToolIds,
            toolResults: toolResults,
            structuredResults: [:],
            conversationInfo: conversationInfo
        )
    }

    private func sessionFilePath(for sessionId: String) -> String? {
        if let cached = pathCache[sessionId], FileManager.default.fileExists(atPath: cached) {
            return cached
        }

        let fileManager = FileManager.default
        let roots = [
            CodexPaths.codexDir.appendingPathComponent("sessions"),
            CodexPaths.codexDir.appendingPathComponent("archived_sessions"),
        ]

        for root in roots {
            if let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: nil) {
                for case let url as URL in enumerator {
                    let fileName = url.lastPathComponent
                    if fileName.hasSuffix(".jsonl") && fileName.contains(sessionId) {
                        pathCache[sessionId] = url.path
                        return url.path
                    }
                }
            }
        }

        return nil
    }

    private func parseMessagePayload(payload: [String: Any], fallbackIndex: Int, timestamp: String?) -> ChatMessage? {
        guard let roleString = payload["role"] as? String,
              let role = ChatRole(rawValue: roleString),
              let contentItems = payload["content"] as? [[String: Any]] else {
            return nil
        }

        let blocks = contentItems.compactMap { item -> MessageBlock? in
            guard let type = item["type"] as? String else { return nil }
            switch type {
            case "input_text":
                return .text(item["text"] as? String ?? "")
            case "output_text":
                return .text(item["text"] as? String ?? "")
            default:
                return nil
            }
        }.filter {
            if case .text(let text) = $0 {
                return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return true
        }

        guard !blocks.isEmpty else { return nil }

        return ChatMessage(
            id: payload["id"] as? String ?? "codex-msg-\(fallbackIndex)",
            role: role,
            timestamp: parseTimestamp(timestamp),
            content: blocks
        )
    }

    private func appendMessage(_ message: ChatMessage, to messages: inout [ChatMessage]) {
        guard let last = messages.last else {
            messages.append(message)
            return
        }

        if shouldMergeDuplicateUserMessage(existing: last, incoming: message) {
            messages[messages.count - 1] = preferredMessage(existing: last, incoming: message)
            return
        }

        messages.append(message)
    }

    private func shouldMergeDuplicateUserMessage(existing: ChatMessage, incoming: ChatMessage) -> Bool {
        guard existing.role == .user, incoming.role == .user else { return false }
        guard existing.textContent == incoming.textContent else { return false }

        let delta = abs(existing.timestamp.timeIntervalSince(incoming.timestamp))
        return delta < 5
    }

    private func preferredMessage(existing: ChatMessage, incoming: ChatMessage) -> ChatMessage {
        let existingImageCount = existing.content.filter {
            if case .image = $0 { return true }
            return false
        }.count
        let incomingImageCount = incoming.content.filter {
            if case .image = $0 { return true }
            return false
        }.count

        if incomingImageCount > existingImageCount {
            return incoming
        }
        if existingImageCount > incomingImageCount {
            return existing
        }
        if incoming.content.count > existing.content.count {
            return incoming
        }
        return existing
    }

    private func parseUserMessageEvent(payload: [String: Any], fallbackIndex: Int, timestamp: String?) -> ChatMessage? {
        var blocks: [MessageBlock] = []

        if let message = payload["message"] as? String,
           !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks.append(.text(message))
        }

        if let images = payload["images"] as? [String] {
            for image in images {
                guard let block = parseDataURLImageBlock(image) else { continue }
                blocks.append(.image(block))
            }
        }

        if let localImages = payload["local_images"] as? [String] {
            for path in localImages where !path.isEmpty {
                blocks.append(.image(ImageBlock(
                    mediaType: mediaType(forLocalPath: path),
                    base64Data: nil,
                    filePath: path
                )))
            }
        }

        guard !blocks.isEmpty else { return nil }

        return ChatMessage(
            id: payload["id"] as? String ?? "codex-user-\(fallbackIndex)",
            role: .user,
            timestamp: parseTimestamp(timestamp),
            content: blocks
        )
    }

    private func parseFunctionCallPayload(payload: [String: Any], fallbackIndex: Int, timestamp: String?) -> ChatMessage? {
        guard let callId = payload["call_id"] as? String,
              let name = payload["name"] as? String else {
            return nil
        }

        var input: [String: String] = [:]
        if let arguments = payload["arguments"] as? String, !arguments.isEmpty {
            input["arguments"] = arguments
        }

        return ChatMessage(
            id: "codex-tool-\(fallbackIndex)-\(callId)",
            role: .assistant,
            timestamp: parseTimestamp(timestamp),
            content: [.toolUse(ToolUseBlock(id: callId, name: name, input: input))]
        )
    }

    private func parseDataURLImageBlock(_ value: String) -> ImageBlock? {
        guard value.hasPrefix("data:"),
              let commaIndex = value.firstIndex(of: ",") else {
            return nil
        }

        let header = String(value[..<commaIndex])
        let bodyStart = value.index(after: commaIndex)
        let body = String(value[bodyStart...])

        let mediaType = header
            .replacingOccurrences(of: "data:", with: "")
            .replacingOccurrences(of: ";base64", with: "")

        guard !body.isEmpty else { return nil }

        return ImageBlock(mediaType: mediaType.isEmpty ? "image/*" : mediaType, base64Data: body, filePath: nil)
    }

    private func mediaType(forLocalPath path: String) -> String {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        case "heic":
            return "image/heic"
        case "bmp":
            return "image/bmp"
        default:
            return "image/*"
        }
    }

    private func parseTimestamp(_ value: String?) -> Date {
        guard let value else { return Date() }
        return ISO8601DateFormatter().date(from: value) ?? Date()
    }

    private func truncate(_ text: String?, maxLength: Int = 80) -> String? {
        guard let text else { return nil }
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard !cleaned.isEmpty else { return nil }
        if cleaned.count > maxLength {
            return String(cleaned.prefix(maxLength - 3)) + "..."
        }
        return cleaned
    }
}
