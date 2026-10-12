import SwiftUI

struct FocusView: View {
    private enum Destination: String, CaseIterable, Identifiable {
        case grow = "Grow"
        case garden = "My Garden"
        var id: Self { self }
    }

    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var focusStore = FocusSessionStore()
    @State private var destination: Destination = .grow

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var progress: Double { focusStore.progress }

    var body: some View {
        VStack(spacing: 14) {
            focusNavigation

            if destination == .grow {
                HStack(spacing: 22) {
                    treeCard
                        .frame(maxWidth: .infinity)
                    timerCard
                        .frame(width: 300)
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
            } else {
                gardenView
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: destination)
        .onReceive(timer) { _ in focusStore.tick() }
    }

    private var focusNavigation: some View {
        HStack {
            HStack(spacing: 3) {
                ForEach(Destination.allCases) { item in
                    Button {
                        destination = item
                    } label: {
                        Label(item.rawValue, systemImage: item == .grow ? "sparkles" : "tree.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(destination == item ? Color.appCard(for: colorScheme) : .clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color.primary.opacity(0.055), in: Capsule())

            Spacer()

            Label("\(focusStore.plantedTrees.count) trees planted", systemImage: "leaf.circle.fill")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.28, green: 0.68, blue: 0.28))
        }
    }

    private var treeCard: some View {
        VStack(spacing: 4) {
            HStack {
                Label("FOCUS GARDEN", systemImage: "leaf.fill")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(.secondary)
                Spacer()
                Label("\(focusStore.plantedTrees.count) planted", systemImage: "tree.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            GrowingTree(progress: progress, variant: focusStore.currentTreeVariant)
                .frame(maxWidth: 390, maxHeight: 350)
                .aspectRatio(1.08, contentMode: .fit)
                .animation(.spring(response: 0.8, dampingFraction: 0.72), value: progress)

            Text(treeMessage)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(treeSubtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 5)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.appCard(for: colorScheme))
                .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.primary.opacity(0.075)))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.07), radius: 20, y: 9)
        )
    }

    private var timerCard: some View {
        VStack(spacing: 22) {
            VStack(spacing: 5) {
                Image(systemName: focusStore.isRunning ? "leaf.fill" : "leaf")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(Color(red: 0.24, green: 0.76, blue: 0.24))
                Text(focusStore.isRunning ? "Stay focused" : focusStore.isFinished ? "Tree complete!" : "Let's focus")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }

            Text(timeText)
                .font(.system(size: 54, weight: .medium, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(LinearGradient(
                                colors: [Color(red: 0.28, green: 0.78, blue: 0.22), Color(red: 0.35, green: 0.90, blue: 0.45)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geometry.size.width * progress)
                    }
                }
                .frame(height: 8)
                Text("\(Int((progress * 100).rounded()))% grown")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Picker("Duration", selection: Binding(
                get: { focusStore.selectedMinutes },
                set: { focusStore.setDuration(minutes: $0) }
            )) {
                Text("15 min").tag(15)
                Text("25 min").tag(25)
                Text("45 min").tag(45)
            }
            .pickerStyle(.segmented)
            .disabled(focusStore.hasStarted)

            Button(action: primaryAction) {
                Label(primaryButtonTitle, systemImage: primaryButtonIcon)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FocusButtonStyle())

            if focusStore.hasStarted && !focusStore.isFinished {
                Button("Reset session", action: focusStore.reset)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 7) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Color.yellow)
                Text("The timer keeps growing your tree while you work.")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.04), in: Capsule())
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.appCard(for: colorScheme))
                .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.primary.opacity(0.075)))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.07), radius: 20, y: 9)
        )
    }

    private var gardenView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your focus garden")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Every tree represents a focus session you completed and claimed.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(focusStore.plantedTrees.reduce(0) { $0 + $1.focusMinutes }) focused minutes")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if focusStore.plantedTrees.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tree")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(Color.green.opacity(0.55))
                    Text("Your garden is ready for its first tree")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("Complete a focus session, claim your tree, and it will be planted here.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Button("Grow a tree") { destination = .grow }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.30, green: 0.72, blue: 0.25))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GardenLandscape(trees: focusStore.plantedTrees)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.appCard(for: colorScheme))
                .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.primary.opacity(0.075)))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.07), radius: 20, y: 9)
        )
    }

    private var timeText: String {
        String(format: "%02d:%02d", focusStore.remainingSeconds / 60, focusStore.remainingSeconds % 60)
    }

    private func primaryAction() {
        if focusStore.isFinished && !focusStore.currentTreeClaimed {
            focusStore.claimTree()
            destination = .garden
        } else {
            focusStore.toggle()
        }
    }

    private var primaryButtonTitle: String {
        if focusStore.isRunning { return "Pause" }
        if focusStore.isFinished && !focusStore.currentTreeClaimed { return "Claim tree" }
        if focusStore.isFinished { return "Grow another tree" }
        if focusStore.hasStarted { return "Resume Focus" }
        return "Focus"
    }

    private var primaryButtonIcon: String {
        if focusStore.isRunning { return "pause.fill" }
        if focusStore.isFinished && !focusStore.currentTreeClaimed { return "gift.fill" }
        return "play.fill"
    }

    private var treeMessage: String {
        if focusStore.isFinished && focusStore.currentTreeClaimed { return "Planted in your garden!" }
        if focusStore.isFinished { return "Your tree is in full bloom!" }
        if focusStore.isRunning { return "Your \(currentTreeName) is growing" }
        if focusStore.hasStarted { return "Your \(currentTreeName) is paused" }
        return "A mystery seed is waiting"
    }

    private var treeSubtitle: String {
        if focusStore.isFinished && focusStore.currentTreeClaimed { return "Beautiful work. This tree is now part of your collection." }
        if focusStore.isFinished { return "Beautiful work. Claim your tree to plant it in the garden." }
        if focusStore.hasStarted { return "Keep the timer running to help your garden flourish." }
        return "Start focusing to discover which tree your seed becomes."
    }

    private var currentTreeName: String {
        ["cherry tree", "golden tree", "lavender tree", "spring tree"][focusStore.currentTreeVariant % 4]
    }
}

private struct LegacyGrowingTree: View {
    let progress: Double
    @Environment(\.colorScheme) private var colorScheme

    private var growth: Double { 0.12 + progress * 0.88 }

    private let blossoms: [(CGFloat, CGFloat, CGFloat, Double)] = [
        (0.50, 0.24, 0.18, 0.12), (0.35, 0.29, 0.17, 0.20), (0.65, 0.30, 0.18, 0.25),
        (0.25, 0.39, 0.15, 0.33), (0.76, 0.40, 0.16, 0.38), (0.46, 0.39, 0.19, 0.42),
        (0.59, 0.43, 0.18, 0.48), (0.17, 0.49, 0.13, 0.54), (0.84, 0.50, 0.13, 0.58),
        (0.31, 0.50, 0.17, 0.62), (0.70, 0.52, 0.16, 0.67), (0.48, 0.52, 0.18, 0.72),
        (0.23, 0.31, 0.10, 0.76), (0.78, 0.31, 0.10, 0.80), (0.41, 0.18, 0.11, 0.84),
        (0.61, 0.18, 0.11, 0.88), (0.12, 0.43, 0.09, 0.92), (0.89, 0.43, 0.09, 0.96)
    ]

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // Floating garden platform.
            let platform = CGRect(x: w * 0.12, y: h * 0.76, width: w * 0.76, height: h * 0.14)
            context.fill(Path(ellipseIn: platform), with: .linearGradient(
                Gradient(colors: [Color(red: 0.62, green: 0.84, blue: 0.31), Color(red: 0.30, green: 0.66, blue: 0.32)]),
                startPoint: CGPoint(x: w * 0.2, y: h * 0.78),
                endPoint: CGPoint(x: w * 0.8, y: h * 0.9)
            ))

            let trunkTop = h * (0.72 - 0.48 * growth)
            var trunk = Path()
            trunk.move(to: CGPoint(x: w * 0.51, y: h * 0.79))
            trunk.addCurve(
                to: CGPoint(x: w * 0.50, y: trunkTop),
                control1: CGPoint(x: w * 0.43, y: h * 0.66),
                control2: CGPoint(x: w * 0.58, y: h * 0.51)
            )
            context.stroke(trunk, with: .linearGradient(
                Gradient(colors: [Color(red: 0.38, green: 0.18, blue: 0.10), Color(red: 0.65, green: 0.34, blue: 0.24)]),
                startPoint: CGPoint(x: w * 0.5, y: h * 0.8),
                endPoint: CGPoint(x: w * 0.5, y: trunkTop)
            ), style: StrokeStyle(lineWidth: 18 * growth + 5, lineCap: .round))

            if growth > 0.28 {
                drawBranch(&context, from: (0.49, 0.57), to: (0.30, 0.39), size: size, width: 9 * growth)
            }
            if growth > 0.42 {
                drawBranch(&context, from: (0.53, 0.52), to: (0.72, 0.35), size: size, width: 10 * growth)
            }
            if growth > 0.58 {
                drawBranch(&context, from: (0.50, 0.43), to: (0.45, 0.24), size: size, width: 8 * growth)
            }

            for (index, blossom) in blossoms.enumerated() where growth >= blossom.3 {
                let pulse = CGFloat(min(1, (growth - blossom.3) * 7 + 0.25))
                let diameter = w * blossom.2 * pulse
                let rect = CGRect(x: w * blossom.0 - diameter / 2, y: h * blossom.1 - diameter / 2, width: diameter, height: diameter)
                let colors = index.isMultiple(of: 3)
                    ? [Color(red: 1.0, green: 0.63, blue: 0.72), Color(red: 0.95, green: 0.38, blue: 0.58)]
                    : [Color(red: 1.0, green: 0.78, blue: 0.83), Color(red: 0.91, green: 0.48, blue: 0.63)]
                context.fill(Path(ellipseIn: rect), with: .radialGradient(
                    Gradient(colors: colors), center: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0, endRadius: diameter / 2
                ))
            }

            // Young sprout leaves are always visible.
            if growth < 0.3 {
                let leafSize = w * 0.07
                context.fill(Path(ellipseIn: CGRect(x: w * 0.49 - leafSize, y: trunkTop - leafSize * 0.4, width: leafSize, height: leafSize * 0.55)), with: .color(.green))
                context.fill(Path(ellipseIn: CGRect(x: w * 0.51, y: trunkTop - leafSize * 0.5, width: leafSize, height: leafSize * 0.55)), with: .color(.green))
            }
        }
        .accessibilityLabel("Focus tree, \(Int((progress * 100).rounded())) percent grown")
    }

    private func drawBranch(
        _ context: inout GraphicsContext,
        from: (CGFloat, CGFloat),
        to: (CGFloat, CGFloat),
        size: CGSize,
        width: CGFloat
    ) {
        var path = Path()
        path.move(to: CGPoint(x: size.width * from.0, y: size.height * from.1))
        path.addLine(to: CGPoint(x: size.width * to.0, y: size.height * to.1))
        context.stroke(path, with: .color(Color(red: 0.55, green: 0.27, blue: 0.18)), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }
}

private struct FocusButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.24, green: 0.73, blue: 0.20), Color(red: 0.34, green: 0.82, blue: 0.28)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
