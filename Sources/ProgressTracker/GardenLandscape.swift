import SwiftUI

/// A floating, expandable isometric island where claimed focus trees live together.
struct GardenLandscape: View {
    let trees: [PlantedTree]
    @State private var selectedTreeID: UUID?

    private struct Tile: Hashable {
        let row: Int
        let column: Int
    }

    private struct Metrics {
        let side: Int
        let tileWidth: CGFloat
        let tileHeight: CGFloat
        let origin: CGPoint
        let treeSize: CGFloat

        func center(of tile: Tile) -> CGPoint {
            CGPoint(
                x: origin.x + CGFloat(tile.column - tile.row) * tileWidth / 2,
                y: origin.y + CGFloat(tile.column + tile.row) * tileHeight / 2
            )
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = metrics(for: proxy.size)
            let plots = treePlots(side: metrics.side)

            ZStack {
                islandBackdrop

                Canvas { context, _ in
                    drawIsland(in: &context, metrics: metrics)
                }

                ForEach(Array(trees.enumerated()), id: \.element.id) { index, tree in
                    if index < plots.count {
                        let tileCenter = metrics.center(of: plots[index])
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedTreeID = selectedTreeID == tree.id ? nil : tree.id
                            }
                        } label: {
                            GrowingTree(progress: 1, variant: tree.variant, showsGardenBase: false)
                                .frame(width: metrics.treeSize, height: metrics.treeSize)
                                .scaleEffect(selectedTreeID == tree.id ? 1.08 : 1)
                                .shadow(color: .black.opacity(0.15), radius: 5, y: 4)
                        }
                        .buttonStyle(.plain)
                        .help("\(tree.name) — \(tree.focusMinutes) focused minutes")
                        // The illustration's roots sit at 79% of its height.
                        .position(x: tileCenter.x, y: tileCenter.y - metrics.treeSize * 0.29)
                    }
                }

                if let tree = selectedTree {
                    treeInfo(tree)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, 14)
                }

                VStack {
                    HStack {
                        Label("FOCUS ISLAND", systemImage: "map.fill")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.ultraThinMaterial, in: Capsule())
                        Spacer()
                    }
                    Spacer()
                }
                .padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.55)))
        }
    }

    private var islandBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.97, blue: 0.87),
                    Color(red: 0.88, green: 0.94, blue: 0.79),
                    Color(red: 0.82, green: 0.91, blue: 0.77)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(0.36))
                .frame(width: 260, height: 260)
                .blur(radius: 30)
                .offset(x: -250, y: -130)

            Circle()
                .fill(Color.mint.opacity(0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 40)
                .offset(x: 280, y: 170)
        }
    }

    private var selectedTree: PlantedTree? {
        guard let selectedTreeID else { return nil }
        return trees.first { $0.id == selectedTreeID }
    }

    private func treeInfo(_ tree: PlantedTree) -> some View {
        HStack(spacing: 9) {
            Circle()
                .fill(treeColor(tree.variant).opacity(0.22))
                .frame(width: 30, height: 30)
                .overlay(Image(systemName: "tree.fill").foregroundStyle(treeColor(tree.variant)))
            VStack(alignment: .leading, spacing: 1) {
                Text(tree.name)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                Text("\(tree.focusMinutes) focused minutes • Planted \(tree.plantedAt.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Button {
                selectedTreeID = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .padding(5)
                    .background(Color.primary.opacity(0.07), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.65)))
        .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
    }

    private func metrics(for size: CGSize) -> Metrics {
        var side = 4
        while side * side - 4 < trees.count { side += 1 }

        let tileWidth = min(126, size.width / (CGFloat(side) + 0.9))
        let tileHeight = tileWidth * 0.49
        let islandHeight = CGFloat(side) * tileHeight
        let originY = max(tileHeight * 0.68, (size.height - islandHeight) / 2 + tileHeight * 0.55)

        return Metrics(
            side: side,
            tileWidth: tileWidth,
            tileHeight: tileHeight,
            origin: CGPoint(x: size.width / 2, y: originY),
            treeSize: min(128, tileWidth * 1.04)
        )
    }

    private func allTiles(side: Int) -> [Tile] {
        var result: [Tile] = []
        for depth in 0...(2 * side - 2) {
            for row in 0..<side {
                let column = depth - row
                guard column >= 0, column < side else { continue }
                // Two missing corners create the modular, expanding-island silhouette.
                if (row == 0 && column == side - 1) || (row == side - 1 && column == 0) { continue }
                result.append(Tile(row: row, column: column))
            }
        }
        return result
    }

    private func waterTiles(side: Int) -> Set<Tile> {
        [Tile(row: side - 1, column: side - 1), Tile(row: side - 2, column: side - 1)]
    }

    private func treePlots(side: Int) -> [Tile] {
        let water = waterTiles(side: side)
        let middle = CGFloat(side - 1) / 2
        return allTiles(side: side)
            .filter { !water.contains($0) }
            .sorted {
                let first = abs(CGFloat($0.row) - middle) + abs(CGFloat($0.column) - middle)
                let second = abs(CGFloat($1.row) - middle) + abs(CGFloat($1.column) - middle)
                if first != second { return first < second }
                return ($0.row + $0.column) < ($1.row + $1.column)
            }
    }

    private func drawIsland(in context: inout GraphicsContext, metrics: Metrics) {
        let water = waterTiles(side: metrics.side)
        let occupied = Set(treePlots(side: metrics.side).prefix(trees.count))

        for (index, tile) in allTiles(side: metrics.side).enumerated() {
            let center = metrics.center(of: tile)
            drawTile(
                in: &context,
                center: center,
                width: metrics.tileWidth,
                height: metrics.tileHeight,
                isWater: water.contains(tile),
                shade: index % 3
            )

            if water.contains(tile) {
                drawWaterDetails(in: &context, center: center, metrics: metrics, bridge: tile.row == metrics.side - 2)
            } else if !occupied.contains(tile) {
                drawDecoration(in: &context, center: center, metrics: metrics, seed: index)
            }
        }
    }

    private func drawTile(
        in context: inout GraphicsContext,
        center: CGPoint,
        width: CGFloat,
        height: CGFloat,
        isWater: Bool,
        shade: Int
    ) {
        let thickness = max(8, height * 0.18)
        let top = CGPoint(x: center.x, y: center.y - height / 2)
        let right = CGPoint(x: center.x + width / 2, y: center.y)
        let bottom = CGPoint(x: center.x, y: center.y + height / 2)
        let left = CGPoint(x: center.x - width / 2, y: center.y)

        let rightSide = Path { path in
            path.move(to: right)
            path.addLine(to: bottom)
            path.addLine(to: CGPoint(x: bottom.x, y: bottom.y + thickness))
            path.addLine(to: CGPoint(x: right.x, y: right.y + thickness))
            path.closeSubpath()
        }
        let leftSide = Path { path in
            path.move(to: left)
            path.addLine(to: bottom)
            path.addLine(to: CGPoint(x: bottom.x, y: bottom.y + thickness))
            path.addLine(to: CGPoint(x: left.x, y: left.y + thickness))
            path.closeSubpath()
        }
        context.fill(leftSide, with: .color(Color(red: 0.49, green: 0.67, blue: 0.31)))
        context.fill(rightSide, with: .color(Color(red: 0.36, green: 0.59, blue: 0.34)))

        let topFace = Path { path in
            path.move(to: top)
            path.addLine(to: right)
            path.addLine(to: bottom)
            path.addLine(to: left)
            path.closeSubpath()
        }
        let grass = [
            Color(red: 0.70, green: 0.84, blue: 0.40),
            Color(red: 0.76, green: 0.87, blue: 0.45),
            Color(red: 0.66, green: 0.81, blue: 0.38)
        ][shade]
        context.fill(topFace, with: .color(isWater ? Color(red: 0.37, green: 0.78, blue: 0.77) : grass))
        context.stroke(topFace, with: .color(.white.opacity(0.20)), lineWidth: 1)
    }

    private func drawWaterDetails(in context: inout GraphicsContext, center: CGPoint, metrics: Metrics, bridge: Bool) {
        for index in 0..<3 {
            let width = metrics.tileWidth * (0.13 + CGFloat(index) * 0.04)
            let y = center.y - metrics.tileHeight * 0.20 + CGFloat(index) * metrics.tileHeight * 0.18
            var ripple = Path()
            ripple.move(to: CGPoint(x: center.x - width, y: y))
            ripple.addQuadCurve(to: CGPoint(x: center.x + width, y: y), control: CGPoint(x: center.x, y: y + 3))
            context.stroke(ripple, with: .color(.white.opacity(0.34)), lineWidth: 1.3)
        }

        guard bridge else { return }
        for index in -2...2 {
            let x = center.x + CGFloat(index) * metrics.tileWidth * 0.075
            var plank = Path()
            plank.move(to: CGPoint(x: x - 9, y: center.y - 9))
            plank.addLine(to: CGPoint(x: x + 9, y: center.y + 9))
            context.stroke(plank, with: .color(Color(red: 0.55, green: 0.32, blue: 0.18)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        }
    }

    private func drawDecoration(in context: inout GraphicsContext, center: CGPoint, metrics: Metrics, seed: Int) {
        if seed.isMultiple(of: 3) {
            // Flower clusters around empty plots.
            let colors: [Color] = [.pink, .yellow, .purple.opacity(0.75), .white]
            for index in 0..<5 {
                let x = center.x - metrics.tileWidth * 0.22 + CGFloat(index) * metrics.tileWidth * 0.09
                let y = center.y + (index.isMultiple(of: 2) ? -2 : 3)
                context.fill(Path(ellipseIn: CGRect(x: x - 2.2, y: y - 2.2, width: 4.4, height: 4.4)), with: .color(colors[(seed + index) % colors.count]))
            }
        } else if seed.isMultiple(of: 4) {
            // Mossy stones.
            for index in 0..<3 {
                let rect = CGRect(
                    x: center.x - metrics.tileWidth * 0.18 + CGFloat(index) * 13,
                    y: center.y - 5 + CGFloat(index % 2) * 4,
                    width: 17,
                    height: 9
                )
                context.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.58, green: 0.62, blue: 0.43)))
            }
        } else {
            // Tufts of tall grass.
            for index in -2...2 {
                let x = center.x + CGFloat(index) * 4
                var blade = Path()
                blade.move(to: CGPoint(x: x, y: center.y + 5))
                blade.addQuadCurve(to: CGPoint(x: x + CGFloat(index) * 0.8, y: center.y - 8), control: CGPoint(x: x + 3, y: center.y - 1))
                context.stroke(blade, with: .color(Color(red: 0.31, green: 0.62, blue: 0.27)), lineWidth: 1.6)
            }
        }
    }

    private func treeColor(_ variant: Int) -> Color {
        [.pink, .orange, .purple, .green][variant % 4]
    }
}
