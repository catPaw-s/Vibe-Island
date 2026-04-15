//
//  PermissionPromptView.swift
//  ClaudeIsland
//
//  Dedicated Dynamic Island approval card for pending tool permissions.
//

import SwiftUI

struct PermissionPromptView: View {
    let session: SessionState
    let onApprove: () -> Void
    let onDeny: () -> Void
    let onOpenChat: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(TerminalColors.amber.opacity(0.9))
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Permission Request")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)

                        Text(session.source.displayName.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(TerminalColors.amber.opacity(0.95))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(TerminalColors.amber.opacity(0.16))
                            )
                    }

                    Text(session.displayTitle)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }

            if let toolName = session.pendingToolName {
                VStack(alignment: .leading, spacing: 4) {
                    Text(MCPToolFormatter.formatToolName(toolName))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(TerminalColors.amber.opacity(0.95))
                        .lineLimit(1)

                    if let input = session.pendingToolInput, !input.isEmpty {
                        Text(input)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(2)
                    } else {
                        Text("This tool is requesting approval.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }

            HStack(spacing: 8) {
                Button(action: onOpenChat) {
                    Label("Open Chat", systemImage: "bubble.left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Button(action: onDeny) {
                    Text("Deny")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onApprove) {
                    Text("Allow")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.92))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct PermissionPromptUnavailableView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Permission expired")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            Text("The request is no longer waiting for approval.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
