//
//  SplashAnimation.swift
//  SDTool
//

import SwiftUI

// MARK: - Splash coordinator — picks a random animation each launch

struct SplashView: View {
    let onComplete: () -> Void

    // Static so it is chosen once per process launch, not per view reinit.
    // This ensures different animations across launches.
    private static var chosenIndex: Int = Int.random(in: 0..<4)

    var body: some View {
        Group {
            switch SplashView.chosenIndex {
            case 0:  TheArchitectSplash(onComplete: onComplete)
            case 1:  StackOverflowSplash(onComplete: onComplete)
            case 2:  LoadingBarSplash(onComplete: onComplete)
            default: WhiteboardSplash(onComplete: onComplete)
            }
        }
        .onAppear {
            // Re-randomise for the NEXT launch so it's always different
            SplashView.chosenIndex = Int.random(in: 0..<4)
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// ANIMATION 1 — "The Architect"
// A stick figure desperately draws system design boxes. They all collapse.
// He holds up a "Good Enough™" sign anyway.
// ─────────────────────────────────────────────────────────────────────────

struct TheArchitectSplash: View {
    let onComplete: () -> Void

    @State private var phase:         Int     = 0   // 0=draw 1=collapse 2=sign 3=done
    @State private var boxOpacity:    [Double] = [0, 0, 0, 0, 0]
    @State private var boxScale:      [CGFloat] = [1, 1, 1, 1, 1]
    @State private var figureWiggle:  Double   = 0
    @State private var signScale:     CGFloat  = 0
    @State private var signRotation:  Double   = -15
    @State private var subtitleOpacity: Double = 0
    @State private var exitOpacity:   Double   = 1

    private let boxes: [(String, Color)] = [
        ("Client", .blue),
        ("API\nGateway", .purple),
        ("DB", .green),
        ("Cache", .orange),
        ("Queue", .red),
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Boxes grid ─────────────────────────────────────
                ZStack {
                    // boxes scattered around
                    ForEach(Array(boxes.enumerated()), id: \.offset) { i, box in
                        boxView(label: box.0, color: box.1)
                            .offset(boxOffset(i))
                            .opacity(boxOpacity[i])
                            .scaleEffect(boxScale[i])
                            .rotationEffect(.degrees(boxScale[i] < 0.5 ? Double(i * 15 - 30) : 0))
                    }

                    // Arrow lines (shown briefly before collapse)
                    if phase == 1 {
                        arrowLines
                            .transition(.opacity)
                    }
                }
                .frame(width: 300, height: 200)

                // ── Stick figure ───────────────────────────────────
                StickFigureView(wiggle: figureWiggle, phase: phase)
                    .frame(width: 80, height: 100)
                    .padding(.top, 8)

                // ── Sign (phase 2) ─────────────────────────────────
                if phase >= 2 {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.yellow)
                            .frame(width: 180, height: 56)
                            .shadow(radius: 4)
                        VStack(spacing: 2) {
                            Text("Good Enough™")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(.black)
                            Text("— every senior engineer ever")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.black.opacity(0.6))
                        }
                    }
                    .scaleEffect(signScale)
                    .rotationEffect(.degrees(signRotation))
                    .padding(.top, 8)
                }

                // ── Subtitle ───────────────────────────────────────
                Text("Loading your architecture toolkit…")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .opacity(subtitleOpacity)
                    .padding(.top, 20)

                Spacer()
            }
        }
        .opacity(exitOpacity)
        .onAppear { runAnimation() }
    }

    // MARK: - Box view

    private func boxView(label: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .stroke(color, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.08))
                )
                .frame(width: 60, height: 40)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
        }
    }

    private func boxOffset(_ i: Int) -> CGSize {
        let positions: [CGSize] = [
            CGSize(width: -110, height: -60),
            CGSize(width: -30,  height: -70),
            CGSize(width:  50,  height: -60),
            CGSize(width: -80,  height:  40),
            CGSize(width:  20,  height:  50),
        ]
        return positions[i]
    }

    private var arrowLines: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let offsets: [CGPoint] = [
                CGPoint(x: cx - 80, y: cy - 40),
                CGPoint(x: cx,      y: cy - 50),
                CGPoint(x: cx + 80, y: cy - 40),
                CGPoint(x: cx - 50, y: cy + 60),
                CGPoint(x: cx + 50, y: cy + 70),
            ]
            let connections = [(0,1),(1,2),(1,3),(2,4)]
            var path = Path()
            for (a, b) in connections {
                path.move(to: offsets[a])
                path.addLine(to: offsets[b])
            }
            ctx.stroke(path, with: .color(.secondary.opacity(0.4)),
                       style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        }
    }

    // MARK: - Animation sequence

    private func runAnimation() {
        // Phase 0: draw boxes one by one
        for i in 0..<boxes.count {
            withAnimation(.spring(duration: 0.3).delay(Double(i) * 0.18)) {
                boxOpacity[i] = 1.0
            }
        }
        // Wiggle figure while drawing
        withAnimation(.easeInOut(duration: 0.3).repeatCount(6, autoreverses: true).delay(0.1)) {
            figureWiggle = 12
        }

        // Phase 1: show arrows briefly
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { phase = 1 }
        }

        // Collapse everything
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            for i in 0..<boxes.count {
                withAnimation(.spring(duration: 0.4, bounce: 0.3).delay(Double(i) * 0.06)) {
                    boxScale[i]   = 0.01
                    boxOpacity[i] = 0
                }
            }
            // Panic wiggle
            withAnimation(.easeInOut(duration: 0.15).repeatCount(8, autoreverses: true)) {
                figureWiggle = 20
            }
        }

        // Phase 2: hold up sign
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation { phase = 2 }
            withAnimation(.spring(duration: 0.5, bounce: 0.5)) {
                signScale    = 1.0
                signRotation = 3
                figureWiggle = 0
            }
            withAnimation(.easeIn(duration: 0.4)) {
                subtitleOpacity = 1
            }
        }

        // Phase 3: exit
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            withAnimation(.easeIn(duration: 0.4)) {
                exitOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                onComplete()
            }
        }
    }
}

// MARK: - Stick figure drawn with Canvas

struct StickFigureView: View {
    let wiggle: Double
    let phase:  Int

    var body: some View {
        Canvas { ctx, size in
            let cx   = size.width  / 2
            let headR: CGFloat = 12
            let headY: CGFloat = headR
            let bodyT: CGFloat = headY + headR
            let bodyB: CGFloat = bodyT + 30
            let color: GraphicsContext.Shading = .color(.primary)
            let sw: CGFloat = 2.5

            // Head
            ctx.stroke(
                Path(ellipseIn: CGRect(x: cx - headR, y: 0, width: headR*2, height: headR*2)),
                with: color, lineWidth: sw
            )

            // Eyes — wide open panic if phase==0, squiggly if phase>=2
            let eyeY = headY - 3
            if phase >= 2 {
                // happy squiggly eyes
                for ex in [cx - 5.0, cx + 3.0] {
                    var p = Path()
                    p.move(to: CGPoint(x: ex, y: eyeY))
                    p.addCurve(to: CGPoint(x: ex + 4, y: eyeY),
                               control1: CGPoint(x: ex + 1, y: eyeY - 3),
                               control2: CGPoint(x: ex + 3, y: eyeY + 3))
                    ctx.stroke(p, with: color, lineWidth: 1.5)
                }
            } else {
                // dot eyes
                for ex in [cx - 4.0, cx + 4.0] {
                    ctx.fill(Path(ellipseIn: CGRect(x: ex-1.5, y: eyeY-1.5, width: 3, height: 3)),
                             with: color)
                }
            }

            // Body
            var body = Path()
            body.move(to: CGPoint(x: cx, y: bodyT))
            body.addLine(to: CGPoint(x: cx, y: bodyB))
            ctx.stroke(body, with: color, lineWidth: sw)

            // Arms — raised in phase >= 2 (holding sign), else drawing frantically
            var leftArm  = Path()
            var rightArm = Path()
            let armY = bodyT + 10
            if phase >= 2 {
                // both arms up holding sign
                leftArm.move(to:  CGPoint(x: cx, y: armY))
                leftArm.addLine(to: CGPoint(x: cx - 22, y: armY - 18))
                rightArm.move(to: CGPoint(x: cx, y: armY))
                rightArm.addLine(to: CGPoint(x: cx + 22, y: armY - 18))
            } else {
                // one arm stretched out drawing
                leftArm.move(to:  CGPoint(x: cx, y: armY))
                leftArm.addLine(to: CGPoint(x: cx - 18, y: armY + 8))
                rightArm.move(to: CGPoint(x: cx, y: armY))
                rightArm.addLine(to: CGPoint(x: cx + 24, y: armY - 12))
            }
            ctx.stroke(leftArm,  with: color, lineWidth: sw)
            ctx.stroke(rightArm, with: color, lineWidth: sw)

            // Legs
            var leftLeg  = Path()
            var rightLeg = Path()
            leftLeg.move(to:   CGPoint(x: cx, y: bodyB))
            leftLeg.addLine(to: CGPoint(x: cx - 14, y: bodyB + 20))
            rightLeg.move(to:  CGPoint(x: cx, y: bodyB))
            rightLeg.addLine(to: CGPoint(x: cx + 14, y: bodyB + 20))
            ctx.stroke(leftLeg,  with: color, lineWidth: sw)
            ctx.stroke(rightLeg, with: color, lineWidth: sw)
        }
        .rotationEffect(.degrees(wiggle))
        .animation(.easeInOut(duration: 0.12).repeatForever(autoreverses: true), value: wiggle)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// ANIMATION 2 — "Stack Overflow"
// A coffee cup fills up as fake code "compiles". When full, the app unlocks.
// Tagline: "Running on caffeine and Stack Overflow since 2024"
// ─────────────────────────────────────────────────────────────────────────

struct StackOverflowSplash: View {
    let onComplete: () -> Void

    @State private var fillLevel:      CGFloat = 0      // 0.0 → 1.0
    @State private var codeLines:      [CodeLine] = []
    @State private var currentLine:    Int     = 0
    @State private var steamOpacity:   Double  = 0
    @State private var overflowOffset: CGFloat = 0
    @State private var taglineOpacity: Double  = 0
    @State private var shakeOffset:    CGFloat = 0
    @State private var exitOpacity:    Double  = 1

    private let fakeLogs: [String] = [
        "brew install brain.exe",
        "Compiling excuses…",
        "Googling the error…",
        "Stack Overflow: 200 OK ✓",
        "Copy-pasting solution…",
        "npm install confidence",
        "Deleting node_modules",
        "Reinstalling node_modules",
        "It works! (no idea why)",
        "Shipping anyway 🚀",
    ]

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.10).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Coffee cup ─────────────────────────────────────
                ZStack(alignment: .bottom) {
                    CoffeeCupShape()
                        .stroke(Color.white.opacity(0.9), lineWidth: 2.5)
                        .frame(width: 100, height: 110)

                    // Coffee fill
                    CoffeeFillShape(level: fillLevel)
                        .fill(
                            LinearGradient(
                                colors: [Color(red:0.42, green:0.26, blue:0.10),
                                         Color(red:0.28, green:0.16, blue:0.06)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: 100, height: 110)
                        .clipShape(CoffeeCupShape())
                        .animation(.easeInOut(duration: 0.4), value: fillLevel)

                    // Steam
                    HStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { i in
                            SteamCurl(delay: Double(i) * 0.3)
                        }
                    }
                    .opacity(steamOpacity)
                    .offset(y: -118)
                }
                .offset(x: shakeOffset)
                .frame(height: 130)

                // ── Tagline ────────────────────────────────────────
                Text("Running on caffeine &\nStack Overflow since 2024")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.9, green: 0.6, blue: 0.2))
                    .multilineTextAlignment(.center)
                    .opacity(taglineOpacity)
                    .padding(.top, 20)

                // ── Fake terminal logs ─────────────────────────────
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(codeLines.enumerated()), id: \.offset) { _, line in
                        HStack(spacing: 6) {
                            Text("›")
                                .foregroundStyle(Color(red: 0.3, green: 0.8, blue: 0.4))
                            Text(line.text)
                                .foregroundStyle(line.isError
                                    ? Color(red: 1, green: 0.4, blue: 0.4)
                                    : Color.white.opacity(0.75))
                        }
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .opacity(line.opacity)
                    }
                }
                .frame(maxWidth: 260, alignment: .leading)
                .padding(.top, 24)
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .opacity(exitOpacity)
        .onAppear { runAnimation() }
    }

    // MARK: - Animation sequence

    private func runAnimation() {
        // Type out fake logs and fill cup simultaneously
        for (i, log) in fakeLogs.enumerated() {
            let delay = Double(i) * 0.28
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeIn(duration: 0.15)) {
                    codeLines.append(CodeLine(text: log, opacity: 1.0,
                                              isError: log.contains("error") || log.contains("Delete")))
                }
                withAnimation(.easeInOut(duration: 0.35)) {
                    fillLevel = min(1.0, CGFloat(i + 1) / CGFloat(fakeLogs.count))
                }
                if fillLevel > 0.3 {
                    withAnimation(.easeIn(duration: 0.5)) { steamOpacity = 0.8 }
                }
            }
        }

        // Cup full — shake and overflow
        let fullTime = Double(fakeLogs.count) * 0.28 + 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + fullTime) {
            // Shake
            withAnimation(.easeInOut(duration: 0.07).repeatCount(6, autoreverses: true)) {
                shakeOffset = 8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                shakeOffset = 0
                withAnimation(.easeIn(duration: 0.3)) { taglineOpacity = 1 }
            }
        }

        // Exit
        DispatchQueue.main.asyncAfter(deadline: .now() + fullTime + 1.6) {
            withAnimation(.easeIn(duration: 0.5)) { exitOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { onComplete() }
        }
    }
}

// MARK: - Coffee cup shape

struct CoffeeCupShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        // Trapezoid cup: wider at top
        p.move(to:    CGPoint(x: w * 0.1,  y: 0))
        p.addLine(to: CGPoint(x: w * 0.9,  y: 0))
        p.addLine(to: CGPoint(x: w * 0.82, y: h))
        p.addLine(to: CGPoint(x: w * 0.18, y: h))
        p.closeSubpath()
        return p
    }
}

struct CoffeeFillShape: Shape {
    var level: CGFloat  // 0 = empty, 1 = full

    var animatableData: CGFloat {
        get { level }
        set { level = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let fillY = h * (1 - level)
        // Match cup trapezoid sides at this y level
        let leftX  = w * 0.1  + (w * 0.08) * (fillY / h)
        let rightX = w * 0.9  - (w * 0.08) * (fillY / h)
        p.move(to:    CGPoint(x: leftX,    y: fillY))
        p.addLine(to: CGPoint(x: rightX,   y: fillY))
        p.addLine(to: CGPoint(x: w * 0.82, y: h))
        p.addLine(to: CGPoint(x: w * 0.18, y: h))
        p.closeSubpath()
        return p
    }
}

// MARK: - Steam curl

struct SteamCurl: View {
    let delay: Double
    @State private var rise: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            CurlPath()
                .stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                .frame(width: 12, height: 24)
                .offset(y: -rise)
                .opacity(opacity)
        }
        .onAppear {
            withAnimation(
                .easeOut(duration: 1.4)
                .repeatForever(autoreverses: false)
                .delay(delay)
            ) {
                rise    = 20
                opacity = 0
            }
            withAnimation(.easeIn(duration: 0.3).delay(delay)) {
                opacity = 0.6
            }
        }
    }
}

struct CurlPath: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.maxX, y: rect.maxY * 0.7),
            control2: CGPoint(x: rect.minX, y: rect.maxY * 0.3)
        )
        return p
    }
}

// MARK: - Data types

struct CodeLine: Identifiable {
    let id      = UUID()
    let text:    String
    var opacity: Double
    let isError: Bool
}

// MARK: ─────────────────────────────────────────────────────────────────────
// ANIMATION 3 — "Loading Bar"
// A classic fake progress bar that gets to 99%… stalls… then rockets to 100%.
// Tagline: "Almost done. (We were never done.)"
// Duration: ~4s
// ─────────────────────────────────────────────────────────────────────────

struct LoadingBarSplash: View {
    let onComplete: () -> Void

    @State private var progress:     Double = 0.0
    @State private var statusText:   String = "Initialising neurons..."
    @State private var showTagline:  Bool   = false
    @State private var pulse:        Bool   = false
    @State private var stuckWiggle:  Double = 0
    @State private var showCheckmark: Bool  = false

    private let stages: [(Double, String, Double)] = [
        (0.25,  "Downloading common sense...",   0.5),
        (0.50,  "Compiling best practices...",   0.5),
        (0.72,  "Reticulating splines...",       0.4),
        (0.88,  "Untangling spaghetti code...",  0.4),
        (0.99,  "Almost there...",               0.5),
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // App icon placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.9), Color.accentColor],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 16, x: 0, y: 8)
                        .scaleEffect(pulse ? 1.04 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)

                    Image(systemName: showCheckmark ? "checkmark" : "cpu")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }

                Text("SD Tool")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                // Progress bar
                VStack(spacing: 10) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.systemFill))
                                .frame(height: 10)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress, height: 10)
                                .animation(.easeInOut(duration: 0.5), value: progress)
                        }
                    }
                    .frame(height: 10)
                    .padding(.horizontal, 40)
                    .offset(x: stuckWiggle)

                    HStack {
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .animation(.none, value: statusText)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .animation(.none, value: progress)
                    }
                    .padding(.horizontal, 40)
                }

                if showTagline {
                    Text("Almost done. (We were never done.)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .italic()
                        .transition(.opacity)
                }

                Spacer()
            }
        }
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
        pulse = true
        var delay = 0.3
        for (target, text, dur) in stages {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation { progress = target }
                statusText = text
            }
            delay += dur
        }
        // Stuck at 99% — wiggle
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeInOut(duration: 0.08).repeatCount(6, autoreverses: true)) {
                stuckWiggle = 6
            }
            showTagline = true
        }
        delay += 0.8
        // Rocket to 100%
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            stuckWiggle = 0
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                progress = 1.0
            }
            statusText = "Ready! ✓"
            withAnimation { showCheckmark = true }
        }
        delay += 0.7
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            onComplete()
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// ANIMATION 4 — "Whiteboard Interview"
// Words appear on a whiteboard one by one as if being written.
// Then the interviewer asks "And what's the time complexity?"
// Engineer writes "O(it works on my machine)"
// Duration: ~4.2s
// ─────────────────────────────────────────────────────────────────────────

struct WhiteboardSplash: View {
    let onComplete: () -> Void

    @State private var visibleLines: Int    = 0
    @State private var showQuestion: Bool   = false
    @State private var showAnswer:   Bool   = false
    @State private var cursorBlink:  Bool   = false
    @State private var boardShake:   Double = 0

    private let boardLines = [
        "struct Solution {",
        "  func solve() {",
        "    // TODO: figure out later",
        "    return 42",
        "  }",
        "}",
    ]

    var body: some View {
        ZStack {
            Color(red: 0.13, green: 0.16, blue: 0.20).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Whiteboard
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.94, green: 0.96, blue: 0.95))
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(0..<boardLines.count, id: \.self) { i in
                            if i < visibleLines {
                                Text(boardLines[i])
                                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                                    .foregroundStyle(lineColor(i))
                                    .transition(.opacity.combined(with: .move(edge: .leading)))
                            }
                        }
                        // Blinking cursor
                        if visibleLines > 0 && visibleLines < boardLines.count {
                            Text("_")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.green)
                                .opacity(cursorBlink ? 1 : 0)
                                .animation(.easeInOut(duration: 0.4).repeatForever(), value: cursorBlink)
                        }
                    }
                    .padding(20)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .padding(.horizontal, 32)
                .offset(x: boardShake)

                Spacer().frame(height: 32)

                // Interviewer question bubble
                if showQuestion {
                    HStack {
                        Text("🧑‍💼")
                            .font(.system(size: 28))
                        Text("\"And what's the time complexity?\"")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 32)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer().frame(height: 12)

                // Answer
                if showAnswer {
                    HStack {
                        Text("🧑‍💻")
                            .font(.system(size: 28))
                        Text("\"O(it works on my machine)\"")
                            .font(.subheadline.italic())
                            .foregroundStyle(Color.green.opacity(0.9))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 32)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()
            }
        }
        .onAppear { runAnimation() }
    }

    private func lineColor(_ index: Int) -> Color {
        let line = boardLines[index]
        if line.contains("struct") || line.contains("func") { return Color(red: 0.4, green: 0.6, blue: 1.0) }
        if line.contains("//")                              { return Color(red: 0.5, green: 0.7, blue: 0.5) }
        if line.contains("return")                         { return Color(red: 1.0, green: 0.5, blue: 0.3) }
        if line.contains("{") || line.contains("}")        { return Color(red: 0.3, green: 0.3, blue: 0.3) }
        return Color(red: 0.2, green: 0.2, blue: 0.2)
    }

    private func runAnimation() {
        cursorBlink = true
        // Type lines one by one
        for i in 1...boardLines.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.28) {
                withAnimation(.easeOut(duration: 0.15)) {
                    visibleLines = i
                }
            }
        }
        let afterCode = Double(boardLines.count) * 0.28 + 0.3

        // Shake board after code is done
        DispatchQueue.main.asyncAfter(deadline: .now() + afterCode) {
            withAnimation(.easeInOut(duration: 0.07).repeatCount(5, autoreverses: true)) {
                boardShake = 5
            }
        }
        // Interviewer asks
        DispatchQueue.main.asyncAfter(deadline: .now() + afterCode + 0.5) {
            withAnimation { showQuestion = true }
        }
        // Engineer answers
        DispatchQueue.main.asyncAfter(deadline: .now() + afterCode + 1.3) {
            withAnimation { showAnswer = true }
        }
        // Done
        DispatchQueue.main.asyncAfter(deadline: .now() + afterCode + 2.2) {
            onComplete()
        }
    }
}
