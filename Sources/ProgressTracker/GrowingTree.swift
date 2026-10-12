import SwiftUI

/// A softly shaded, isometric cherry tree that grows with the focus timer.
struct GrowingTree: View {
    let progress: Double
    var variant: Int = 0
    var showsGardenBase = true
    @Environment(\.colorScheme) private var colorScheme

    private var growth: CGFloat { 0.18 + CGFloat(progress) * 0.82 }

    private let clusters: [(x: CGFloat, y: CGFloat, size: CGFloat, appears: Double)] = [
        (0.50, 0.20, 1.04, 0.04), (0.39, 0.24, 0.94, 0.09), (0.61, 0.25, 1.00, 0.14),
        (0.29, 0.31, 0.92, 0.19), (0.71, 0.32, 0.94, 0.24), (0.46, 0.31, 1.08, 0.29),
        (0.57, 0.34, 1.02, 0.34), (0.21, 0.40, 0.84, 0.39), (0.79, 0.41, 0.88, 0.44),
        (0.34, 0.41, 1.00, 0.49), (0.66, 0.43, 1.02, 0.54), (0.47, 0.44, 1.06, 0.59),
        (0.25, 0.25, 0.72, 0.64), (0.75, 0.27, 0.72, 0.69), (0.42, 0.16, 0.72, 0.74),
        (0.59, 0.16, 0.72, 0.79), (0.15, 0.35, 0.68, 0.84), (0.85, 0.36, 0.68, 0.89),
        (0.27, 0.47, 0.70, 0.92), (0.74, 0.48, 0.68, 0.95)
    ]

    var body: some View {
        Canvas { context, size in
            if showsGardenBase {
                drawPlatform(in: &context, size: size)
                drawGardenDetails(in: &context, size: size)
            }
            drawTree(in: &context, size: size)
            if showsGardenBase {
                drawFallenPetals(in: &context, size: size)
            }
        }
        .drawingGroup()
        .accessibilityLabel("Focus tree, \(Int((progress * 100).rounded())) percent grown")
    }

    private func point(_ x: CGFloat, _ y: CGFloat, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * x, y: size.height * y)
    }

    /// Scales the tree upward from its roots while leaving the garden unchanged.
    private func treePoint(_ x: CGFloat, _ y: CGFloat, in size: CGSize) -> CGPoint {
        let baseX: CGFloat = 0.50
        let baseY: CGFloat = 0.79
        let horizontalGrowth = 0.46 + growth * 0.54
        return point(
            baseX + (x - baseX) * horizontalGrowth,
            baseY + (y - baseY) * growth,
            in: size
        )
    }

    private func drawPlatform(in context: inout GraphicsContext, size: CGSize) {
        let top = Path { path in
            path.move(to: point(0.50, 0.69, in: size))
            path.addLine(to: point(0.94, 0.82, in: size))
            path.addLine(to: point(0.50, 0.96, in: size))
            path.addLine(to: point(0.06, 0.82, in: size))
            path.closeSubpath()
        }
        let leftSide = Path { path in
            path.move(to: point(0.06, 0.82, in: size))
            path.addLine(to: point(0.50, 0.96, in: size))
            path.addLine(to: point(0.50, 1.00, in: size))
            path.addLine(to: point(0.06, 0.86, in: size))
            path.closeSubpath()
        }
        let rightSide = Path { path in
            path.move(to: point(0.50, 0.96, in: size))
            path.addLine(to: point(0.94, 0.82, in: size))
            path.addLine(to: point(0.94, 0.86, in: size))
            path.addLine(to: point(0.50, 1.00, in: size))
            path.closeSubpath()
        }

        context.fill(leftSide, with: .linearGradient(
            Gradient(colors: [Color(red: 0.54, green: 0.75, blue: 0.29), Color(red: 0.37, green: 0.65, blue: 0.38)]),
            startPoint: point(0.1, 0.82, in: size), endPoint: point(0.5, 1.0, in: size)
        ))
        context.fill(rightSide, with: .linearGradient(
            Gradient(colors: [Color(red: 0.47, green: 0.72, blue: 0.30), Color(red: 0.28, green: 0.59, blue: 0.43)]),
            startPoint: point(0.9, 0.82, in: size), endPoint: point(0.5, 1.0, in: size)
        ))
        context.fill(top, with: .linearGradient(
            Gradient(colors: [Color(red: 0.78, green: 0.88, blue: 0.38), Color(red: 0.58, green: 0.78, blue: 0.31)]),
            startPoint: point(0.42, 0.70, in: size), endPoint: point(0.58, 0.96, in: size)
        ))

        let shadow = CGRect(x: size.width * 0.31, y: size.height * 0.76, width: size.width * 0.43, height: size.height * 0.10)
        context.fill(Path(ellipseIn: shadow), with: .color(.black.opacity(colorScheme == .dark ? 0.18 : 0.10)))
    }

    private func drawGardenDetails(in context: inout GraphicsContext, size: CGSize) {
        // Rounded stones around the roots.
        drawRock(in: &context, center: point(0.31, 0.81, in: size), width: size.width * 0.17, height: size.height * 0.11)
        drawRock(in: &context, center: point(0.70, 0.84, in: size), width: size.width * 0.15, height: size.height * 0.09)
        drawRock(in: &context, center: point(0.63, 0.91, in: size), width: size.width * 0.12, height: size.height * 0.05)
        drawRock(in: &context, center: point(0.35, 0.92, in: size), width: size.width * 0.11, height: size.height * 0.045)

        // Small blades make the platform feel planted rather than empty.
        let grass: [(CGFloat, CGFloat, CGFloat)] = [
            (0.18, 0.82, -0.02), (0.22, 0.85, 0.01), (0.28, 0.89, -0.015),
            (0.40, 0.88, -0.02), (0.44, 0.91, 0.018), (0.57, 0.90, -0.018),
            (0.76, 0.85, 0.02), (0.82, 0.82, -0.01), (0.69, 0.78, 0.015)
        ]
        for (x, y, lean) in grass {
            var blade = Path()
            blade.move(to: point(x, y, in: size))
            blade.addQuadCurve(to: point(x + lean, y - 0.045, in: size), control: point(x + lean * 1.4, y - 0.022, in: size))
            context.stroke(blade, with: .color(Color(red: 0.25, green: 0.61, blue: 0.24)), style: StrokeStyle(lineWidth: max(1.5, size.width * 0.006), lineCap: .round))
        }

        // A tiny stone lantern, inspired by a Japanese garden.
        let lanternX = size.width * 0.77
        let lanternY = size.height * 0.74
        let stone = Color(red: 0.64, green: 0.64, blue: 0.45)
        context.fill(Path(roundedRect: CGRect(x: lanternX - size.width * 0.025, y: lanternY, width: size.width * 0.05, height: size.height * 0.105), cornerRadius: 3), with: .color(stone))
        context.fill(Path(ellipseIn: CGRect(x: lanternX - size.width * 0.065, y: lanternY - size.height * 0.012, width: size.width * 0.13, height: size.height * 0.038)), with: .color(stone.opacity(0.92)))
        context.fill(Path(roundedRect: CGRect(x: lanternX - size.width * 0.045, y: lanternY - size.height * 0.065, width: size.width * 0.09, height: size.height * 0.06), cornerRadius: 5), with: .linearGradient(
            Gradient(colors: [Color(red: 0.95, green: 0.85, blue: 0.45), stone]),
            startPoint: CGPoint(x: lanternX, y: lanternY - size.height * 0.06), endPoint: CGPoint(x: lanternX, y: lanternY)
        ))
        context.fill(Path(ellipseIn: CGRect(x: lanternX - size.width * 0.06, y: lanternY - size.height * 0.09, width: size.width * 0.12, height: size.height * 0.035)), with: .color(stone))
    }

    private func drawRock(in context: inout GraphicsContext, center: CGPoint, width: CGFloat, height: CGFloat) {
        let rect = CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
        context.fill(Path(ellipseIn: rect), with: .linearGradient(
            Gradient(colors: [Color(red: 0.70, green: 0.72, blue: 0.48), Color(red: 0.48, green: 0.55, blue: 0.37)]),
            startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
        ))
        let highlight = CGRect(x: rect.minX + width * 0.20, y: rect.minY + height * 0.14, width: width * 0.34, height: height * 0.16)
        context.fill(Path(ellipseIn: highlight), with: .color(.white.opacity(0.16)))
    }

    private func drawTree(in context: inout GraphicsContext, size: CGSize) {
        let branchColor = Color(red: 0.39, green: 0.18, blue: 0.13)
        let branchLight = Color(red: 0.64, green: 0.32, blue: 0.27)

        if progress > 0.08 { drawBranch(in: &context, size: size, from: (0.49, 0.60), control: (0.37, 0.49), to: (0.24, 0.35), width: 0.026, color: branchColor) }
        if progress > 0.16 { drawBranch(in: &context, size: size, from: (0.53, 0.57), control: (0.65, 0.48), to: (0.76, 0.33), width: 0.028, color: branchColor) }
        if progress > 0.27 { drawBranch(in: &context, size: size, from: (0.50, 0.48), control: (0.45, 0.35), to: (0.45, 0.19), width: 0.021, color: branchColor) }
        if progress > 0.38 { drawBranch(in: &context, size: size, from: (0.57, 0.47), control: (0.66, 0.39), to: (0.68, 0.23), width: 0.017, color: branchLight) }
        if progress > 0.50 { drawBranch(in: &context, size: size, from: (0.39, 0.48), control: (0.29, 0.43), to: (0.18, 0.40), width: 0.014, color: branchLight) }
        if progress > 0.62 { drawBranch(in: &context, size: size, from: (0.62, 0.43), control: (0.76, 0.42), to: (0.84, 0.39), width: 0.012, color: branchLight) }

        // A broad, curved trunk silhouette gives the tree weight and depth.
        let trunk = Path { path in
            path.move(to: treePoint(0.40, 0.82, in: size))
            path.addCurve(to: treePoint(0.47, 0.55, in: size), control1: treePoint(0.43, 0.76, in: size), control2: treePoint(0.41, 0.64, in: size))
            path.addCurve(to: treePoint(0.48, 0.29, in: size), control1: treePoint(0.52, 0.47, in: size), control2: treePoint(0.45, 0.37, in: size))
            path.addCurve(to: treePoint(0.53, 0.55, in: size), control1: treePoint(0.55, 0.37, in: size), control2: treePoint(0.56, 0.46, in: size))
            path.addCurve(to: treePoint(0.61, 0.81, in: size), control1: treePoint(0.57, 0.66, in: size), control2: treePoint(0.55, 0.75, in: size))
            path.addQuadCurve(to: treePoint(0.52, 0.79, in: size), control: treePoint(0.57, 0.84, in: size))
            path.addQuadCurve(to: treePoint(0.40, 0.82, in: size), control: treePoint(0.46, 0.86, in: size))
            path.closeSubpath()
        }
        context.fill(trunk, with: .linearGradient(
            Gradient(colors: [Color(red: 0.34, green: 0.13, blue: 0.10), Color(red: 0.67, green: 0.31, blue: 0.27), Color(red: 0.42, green: 0.17, blue: 0.13)]),
            startPoint: treePoint(0.39, 0.60, in: size), endPoint: treePoint(0.62, 0.62, in: size)
        ))

        var trunkGlow = Path()
        trunkGlow.move(to: treePoint(0.46, 0.77, in: size))
        trunkGlow.addCurve(to: treePoint(0.50, 0.40, in: size), control1: treePoint(0.45, 0.66, in: size), control2: treePoint(0.52, 0.55, in: size))
        context.stroke(trunkGlow, with: .color(Color(red: 0.84, green: 0.45, blue: 0.39).opacity(0.55)), style: StrokeStyle(lineWidth: max(2, size.width * 0.018 * growth), lineCap: .round))

        // At the beginning of a session, the bare tree carries two fresh leaves.
        if progress < 0.08 {
            drawLeaf(in: &context, center: treePoint(0.45, 0.30, in: size), size: size.width * 0.055, angle: -1)
            drawLeaf(in: &context, center: treePoint(0.53, 0.31, in: size), size: size.width * 0.055, angle: 1)
        }

        for (index, cluster) in clusters.enumerated() where progress >= cluster.appears {
            let reveal = CGFloat(min(1, (progress - cluster.appears) * 9 + 0.20))
            let center = treePoint(cluster.x, cluster.y, in: size)
            drawBlossomCluster(in: &context, center: center, radius: size.width * 0.052 * cluster.size * reveal, seed: index)
        }
    }

    private func drawBranch(
        in context: inout GraphicsContext,
        size: CGSize,
        from: (CGFloat, CGFloat),
        control: (CGFloat, CGFloat),
        to: (CGFloat, CGFloat),
        width: CGFloat,
        color: Color
    ) {
        var branch = Path()
        branch.move(to: treePoint(from.0, from.1, in: size))
        branch.addQuadCurve(to: treePoint(to.0, to.1, in: size), control: treePoint(control.0, control.1, in: size))
        context.stroke(branch, with: .color(color), style: StrokeStyle(lineWidth: max(2, size.width * width * growth), lineCap: .round))
    }

    private func drawBlossomCluster(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, seed: Int) {
        let offsets: [(CGFloat, CGFloat, CGFloat)] = [
            (-0.64, 0.05, 0.72), (-0.35, -0.45, 0.82), (0.08, -0.58, 0.78),
            (0.47, -0.32, 0.86), (0.62, 0.20, 0.74), (0.28, 0.48, 0.82),
            (-0.26, 0.50, 0.78), (0.00, 0.00, 1.00)
        ]

        // A few muted leaves peek through the flowers and add contrast.
        if seed.isMultiple(of: 2) {
            drawLeaf(in: &context, center: CGPoint(x: center.x - radius * 0.7, y: center.y + radius * 0.25), size: radius * 0.75, angle: -1)
        }
        if seed.isMultiple(of: 3) {
            drawLeaf(in: &context, center: CGPoint(x: center.x + radius * 0.65, y: center.y - radius * 0.10), size: radius * 0.65, angle: 1)
        }

        for (index, item) in offsets.enumerated() {
            let bloomCenter = CGPoint(x: center.x + item.0 * radius, y: center.y + item.1 * radius)
            drawBloom(in: &context, center: bloomCenter, radius: radius * 0.48 * item.2, alternate: (seed + index).isMultiple(of: 3))
        }
    }

    private func drawBloom(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat, alternate: Bool) {
        let palettes: [(Color, Color)] = [
            (Color(red: 1.00, green: 0.75, blue: 0.82), Color(red: 0.88, green: 0.40, blue: 0.55)),
            (Color(red: 1.00, green: 0.86, blue: 0.48), Color(red: 0.92, green: 0.58, blue: 0.20)),
            (Color(red: 0.86, green: 0.73, blue: 1.00), Color(red: 0.57, green: 0.42, blue: 0.84)),
            (Color(red: 0.72, green: 0.94, blue: 0.78), Color(red: 0.31, green: 0.69, blue: 0.53))
        ]
        let palette = palettes[variant % palettes.count]
        let pale = alternate ? palette.0.opacity(0.88) : palette.0
        let shaded = alternate ? palette.1.opacity(0.82) : palette.1

        for petal in 0..<5 {
            let angle = CGFloat(petal) * (.pi * 2 / 5) - .pi / 2
            let petalCenter = CGPoint(x: center.x + cos(angle) * radius * 0.48, y: center.y + sin(angle) * radius * 0.48)
            let rect = CGRect(x: petalCenter.x - radius * 0.48, y: petalCenter.y - radius * 0.40, width: radius * 0.96, height: radius * 0.80)
            context.fill(Path(ellipseIn: rect), with: .linearGradient(
                Gradient(colors: [pale, shaded]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            ))
        }
        context.fill(Path(ellipseIn: CGRect(x: center.x - radius * 0.18, y: center.y - radius * 0.18, width: radius * 0.36, height: radius * 0.36)), with: .color(Color(red: 1.0, green: 0.82, blue: 0.36)))
    }

    private func drawLeaf(in context: inout GraphicsContext, center: CGPoint, size: CGFloat, angle: CGFloat) {
        let leaf = Path { path in
            path.move(to: CGPoint(x: center.x - size * 0.55 * angle, y: center.y))
            path.addQuadCurve(to: CGPoint(x: center.x + size * 0.55 * angle, y: center.y), control: CGPoint(x: center.x, y: center.y - size * 0.42))
            path.addQuadCurve(to: CGPoint(x: center.x - size * 0.55 * angle, y: center.y), control: CGPoint(x: center.x, y: center.y + size * 0.34))
        }
        context.fill(leaf, with: .linearGradient(
            Gradient(colors: [Color(red: 0.40, green: 0.68, blue: 0.29), Color(red: 0.22, green: 0.48, blue: 0.22)]),
            startPoint: CGPoint(x: center.x, y: center.y - size / 2), endPoint: CGPoint(x: center.x, y: center.y + size / 2)
        ))
    }

    private func drawFallenPetals(in context: inout GraphicsContext, size: CGSize) {
        let petals: [(CGFloat, CGFloat, CGFloat, Double)] = [
            (0.22, 0.80, 0.010, 0.30), (0.74, 0.87, 0.012, 0.42), (0.39, 0.90, 0.009, 0.55),
            (0.61, 0.83, 0.011, 0.65), (0.30, 0.86, 0.008, 0.76), (0.81, 0.80, 0.009, 0.88)
        ]
        for (x, y, scale, appears) in petals where progress >= appears {
            let rect = CGRect(x: size.width * (x - scale), y: size.height * (y - scale * 0.5), width: size.width * scale * 2, height: size.height * scale)
            context.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.96, green: 0.54, blue: 0.65)))
        }
    }
}
