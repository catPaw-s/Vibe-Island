//
//  NotchHeaderView.swift
//  ClaudeIsland
//
//  Header bar for the dynamic island
//

import Combine
import SwiftUI

struct ClaudeCrabIcon: View {
    let size: CGFloat
    let color: Color
    var animateLegs: Bool = false

    @State private var legPhase: Int = 0

    // Timer for leg animation
    private let legTimer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()

    init(size: CGFloat = 16, color: Color = Color(red: 0.85, green: 0.47, blue: 0.34), animateLegs: Bool = false) {
        self.size = size
        self.color = color
        self.animateLegs = animateLegs
    }

    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 52.0  // Original viewBox height is 52
            let xOffset = (canvasSize.width - 66 * scale) / 2

            // Left antenna
            let leftAntenna = Path { p in
                p.addRect(CGRect(x: 0, y: 13, width: 6, height: 13))
            }.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xOffset / scale, y: 0))
            context.fill(leftAntenna, with: .color(color))

            // Right antenna
            let rightAntenna = Path { p in
                p.addRect(CGRect(x: 60, y: 13, width: 6, height: 13))
            }.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xOffset / scale, y: 0))
            context.fill(rightAntenna, with: .color(color))

            // Animated legs - alternating up/down pattern for walking effect
            // Legs stay attached to body (y=39), only height changes
            let baseLegPositions: [CGFloat] = [6, 18, 42, 54]
            let baseLegHeight: CGFloat = 13

            // Height offsets: positive = longer leg (down), negative = shorter leg (up)
            let legHeightOffsets: [[CGFloat]] = [
                [3, -3, 3, -3],   // Phase 0: alternating
                [0, 0, 0, 0],     // Phase 1: neutral
                [-3, 3, -3, 3],   // Phase 2: alternating (opposite)
                [0, 0, 0, 0],     // Phase 3: neutral
            ]

            let currentHeightOffsets = animateLegs ? legHeightOffsets[legPhase % 4] : [CGFloat](repeating: 0, count: 4)

            for (index, xPos) in baseLegPositions.enumerated() {
                let heightOffset = currentHeightOffsets[index]
                let legHeight = baseLegHeight + heightOffset
                let leg = Path { p in
                    p.addRect(CGRect(x: xPos, y: 39, width: 6, height: legHeight))
                }.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xOffset / scale, y: 0))
                context.fill(leg, with: .color(color))
            }

            // Main body
            let body = Path { p in
                p.addRect(CGRect(x: 6, y: 0, width: 54, height: 39))
            }.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xOffset / scale, y: 0))
            context.fill(body, with: .color(color))

            // Left eye
            let leftEye = Path { p in
                p.addRect(CGRect(x: 12, y: 13, width: 6, height: 6.5))
            }.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xOffset / scale, y: 0))
            context.fill(leftEye, with: .color(.black))

            // Right eye
            let rightEye = Path { p in
                p.addRect(CGRect(x: 48, y: 13, width: 6, height: 6.5))
            }.applying(CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: xOffset / scale, y: 0))
            context.fill(rightEye, with: .color(.black))
        }
        .frame(width: size * (66.0 / 52.0), height: size)
        .onReceive(legTimer) { _ in
            if animateLegs {
                legPhase = (legPhase + 1) % 4
            }
        }
    }
}

struct CodexGlyphIcon: View {
    let size: CGFloat
    let color: Color
    var animate: Bool = false

    @State private var phase: Int = 0
    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    init(size: CGFloat = 16, color: Color = TerminalColors.blue, animate: Bool = false) {
        self.size = size
        self.color = color
        self.animate = animate
    }

    var body: some View {
        Canvas { context, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize).insetBy(dx: canvasSize.width * 0.06, dy: canvasSize.height * 0.08)
            let pulse = animate ? pulseValue(for: phase) : 0
            let floatOffset = animate ? sin(Double(phase) * .pi / 3.0) * rect.height * 0.025 : 0
            let animatedRect = rect.offsetBy(dx: 0, dy: floatOffset)
            let cloud = codexCloudPath(in: animatedRect)

            let gradient = Gradient(colors: [
                Color(red: 0.71, green: 0.62, blue: 1.0),
                Color(red: 0.36, green: 0.50, blue: 1.0),
                Color(red: 0.17, green: 0.21, blue: 0.98),
            ])
            context.fill(
                cloud,
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: animatedRect.midX, y: animatedRect.minY),
                    endPoint: CGPoint(x: animatedRect.midX, y: animatedRect.maxY)
                )
            )

            let glowAlpha = animate ? (0.18 + 0.12 * pulse) : 0.16
            context.stroke(
                cloud,
                with: .color(Color.white.opacity(glowAlpha)),
                lineWidth: max(1, animatedRect.width * 0.03)
            )

            let chevronShift = animate ? animatedRect.width * 0.018 * pulse : 0
            let chevron = codexChevronPath(in: animatedRect.offsetBy(dx: chevronShift, dy: 0))
            context.stroke(
                chevron,
                with: .color(.white.opacity(0.96)),
                style: StrokeStyle(lineWidth: max(1.8, animatedRect.width * 0.085), lineCap: .round, lineJoin: .round)
            )

            let dashRect = CGRect(
                x: animatedRect.midX + animatedRect.width * 0.06,
                y: animatedRect.midY - animatedRect.height * 0.05,
                width: animatedRect.width * (0.18 + 0.07 * (animate ? pulse : 0)),
                height: max(2, animatedRect.height * 0.08)
            )
            let dash = Path(roundedRect: dashRect, cornerRadius: dashRect.height / 2)
            context.fill(dash, with: .color(.white.opacity(0.84 + 0.12 * (animate ? pulse : 0))))
        }
        .frame(width: size * 1.95, height: size * 1.42, alignment: .center)
        .onReceive(timer) { _ in
            if animate {
                phase = (phase + 1) % symbols.count
                }
            }
    }

    private var symbols: [Int] {
        [0, 1, 2, 3, 4, 5]
    }

    private func pulseValue(for phase: Int) -> CGFloat {
        let values: [CGFloat] = [0.15, 0.55, 1.0, 0.7, 0.35, 0.15]
        return values[phase % values.count]
    }

    private func codexCloudPath(in rect: CGRect) -> Path {
        return Path { p in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let petals = 6
            let innerRadius = min(rect.width, rect.height) * 0.36
            let outerRadius = min(rect.width, rect.height) * 0.66

            for index in 0..<petals {
                let angle = CGFloat(index) * (.pi * 2 / CGFloat(petals)) - .pi / 2
                let nextAngle = CGFloat(index + 1) * (.pi * 2 / CGFloat(petals)) - .pi / 2
                let midAngle = (angle + nextAngle) / 2

                let innerPoint = CGPoint(
                    x: center.x + cos(angle) * innerRadius,
                    y: center.y + sin(angle) * innerRadius
                )
                let nextInnerPoint = CGPoint(
                    x: center.x + cos(nextAngle) * innerRadius,
                    y: center.y + sin(nextAngle) * innerRadius
                )
                let outerPoint = CGPoint(
                    x: center.x + cos(midAngle) * outerRadius,
                    y: center.y + sin(midAngle) * outerRadius
                )

                if index == 0 {
                    p.move(to: innerPoint)
                }

                p.addQuadCurve(to: nextInnerPoint, control: outerPoint)
            }

            p.closeSubpath()
        }
    }

    private func codexChevronPath(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.midY - rect.height * 0.16))
            p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.40, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.30, y: rect.midY + rect.height * 0.16))
        }
    }
}

// Pixel art permission indicator icon
struct PermissionIndicatorIcon: View {
    let size: CGFloat
    let color: Color

    init(size: CGFloat = 14, color: Color = Color(red: 0.11, green: 0.12, blue: 0.13)) {
        self.size = size
        self.color = color
    }

    // Visible pixel positions from the SVG (at 30x30 scale)
    private let pixels: [(CGFloat, CGFloat)] = [
        (7, 7), (7, 11),           // Left column
        (11, 3),                    // Top left
        (15, 3), (15, 19), (15, 27), // Center column
        (19, 3), (19, 15),          // Right of center
        (23, 7), (23, 11)           // Right column
    ]

    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 30.0
            let pixelSize: CGFloat = 4 * scale

            for (x, y) in pixels {
                let rect = CGRect(
                    x: x * scale - pixelSize / 2,
                    y: y * scale - pixelSize / 2,
                    width: pixelSize,
                    height: pixelSize
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}

// Pixel art "ready for input" indicator icon (checkmark/done shape)
struct ReadyForInputIndicatorIcon: View {
    let size: CGFloat
    let color: Color

    init(size: CGFloat = 14, color: Color = TerminalColors.green) {
        self.size = size
        self.color = color
    }

    // Checkmark shape pixel positions (at 30x30 scale)
    private let pixels: [(CGFloat, CGFloat)] = [
        (5, 15),                    // Start of checkmark
        (9, 19),                    // Down stroke
        (13, 23),                   // Bottom of checkmark
        (17, 19),                   // Up stroke begins
        (21, 15),                   // Up stroke
        (25, 11),                   // Up stroke
        (29, 7)                     // End of checkmark
    ]

    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 30.0
            let pixelSize: CGFloat = 4 * scale

            for (x, y) in pixels {
                let rect = CGRect(
                    x: x * scale - pixelSize / 2,
                    y: y * scale - pixelSize / 2,
                    width: pixelSize,
                    height: pixelSize
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
        .frame(width: size, height: size)
    }
}
