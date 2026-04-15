//
//  ProcessingSpinner.swift
//  ClaudeIsland
//
//  Animated symbol spinner for processing state
//

import Combine
import SwiftUI

struct ProcessingSpinner: View {
    let source: EditorSource
    @State private var phase: Int = 0

    private let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()

    init(source: EditorSource = .claude) {
        self.source = source
    }

    private var symbols: [String] {
        switch source {
        case .claude:
            return ["·", "✢", "✳", "∗", "✻", "✽"]
        case .codex:
            return ["[·]", "[•]", "[+]", "[×]", "[•]", "[·]"]
        }
    }

    private var color: Color {
        switch source {
        case .claude:
            return Color(red: 0.85, green: 0.47, blue: 0.34)
        case .codex:
            return TerminalColors.blue
        }
    }

    var body: some View {
        Text(symbols[phase % symbols.count])
            .font(.system(size: source == .codex ? 10 : 12, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .frame(width: source == .codex ? 20 : 12, alignment: .center)
            .fixedSize(horizontal: true, vertical: false)
            .onReceive(timer) { _ in
                phase = (phase + 1) % symbols.count
            }
    }
}

#Preview {
    ProcessingSpinner()
        .frame(width: 30, height: 30)
        .background(.black)
}
