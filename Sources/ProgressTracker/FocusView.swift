import SwiftUI

struct FocusView: View {
    private enum Destination: String, CaseIterable, Identifiable {
        case grow = "Grow"
        case garden = "My Garden"
        var id: Self { self }
    }

    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var focusStore = FocusSessionStore()
    @StateObject private var ambientAudio = AmbientAudioPlayer()
    @State private var destination: Destination = .grow
    @State private var isWatering = false
    @State private var showThoughtEditor = false
    @State private var thoughtDraft = ""

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var progress: Double { focusStore.progress }
    private var treeProgress: Double { focusStore.isBreak ? 1 : progress }

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
        .sheet(isPresented: $showThoughtEditor) {
            wateringThoughtSheet
        }
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

            ZStack {
                GrowingTree(progress: treeProgress, variant: focusStore.currentTreeVariant)
                    .frame(maxWidth: 390, maxHeight: 350)
                    .aspectRatio(1.08, contentMode: .fit)
                    .animation(.spring(response: 0.8, dampingFraction: 0.72), value: treeProgress)

                if isWatering {
                    WateringEffect()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .dropDestination(for: String.self) { items, _ in
                guard items.contains("progress-tracker.watering-can") else { return false }
                thoughtDraft = ""
                showThoughtEditor = true
                return true
            }

            Text(treeMessage)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(treeSubtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                Label("Drag bottle to water", systemImage: "waterbottle.fill")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.22, green: 0.58, blue: 0.78))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.cyan.opacity(0.10), in: Capsule())
                    .draggable("progress-tracker.watering-can") {
                        Label("Drop bottle on the tree", systemImage: "waterbottle.fill")
                            .padding(10)
                            .background(.regularMaterial, in: Capsule())
                    }

                if !focusStore.sessionThoughts.isEmpty {
                    Label("\(focusStore.sessionThoughts.count) thoughts", systemImage: "note.text")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 3)
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
        VStack(spacing: 15) {
            VStack(spacing: 5) {
                Image(systemName: timerIcon)
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(focusStore.isBreak ? Color.cyan : Color(red: 0.24, green: 0.76, blue: 0.24))
                Text(timerTitle)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }

            if !focusStore.isBreak {
                TextField("Name this session and tree…", text: Binding(
                    get: { focusStore.sessionName },
                    set: { focusStore.setSessionName($0) }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.045), in: Capsule())
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
                Text(focusStore.isBreak ? "\(Int((progress * 100).rounded()))% recharged" : "\(Int((progress * 100).rounded()))% grown")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            if !focusStore.isBreak {
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
            }

            musicControl

            Button(action: primaryAction) {
                Label(primaryButtonTitle, systemImage: primaryButtonIcon)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FocusButtonStyle())

            if focusStore.isBreak && !focusStore.isFinished {
                Button("Skip break and start focusing", action: focusStore.startNextWork)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            } else if !focusStore.isBreak && focusStore.isFinished && focusStore.currentTreeClaimed {
                Button("Skip break • Next focus", action: focusStore.startNextWork)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            } else if focusStore.hasStarted && !focusStore.isFinished {
                Button("Reset session", action: focusStore.reset)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 7) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(Color.yellow)
                Text(focusStore.isBreak ? "Rest now—the next seed will be ready in five minutes." : "A sound will play when your focus session is complete.")
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

    private var musicControl: some View {
        HStack(spacing: 9) {
            Button(action: ambientAudio.toggle) {
                Image(systemName: ambientAudio.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 25, height: 25)
                    .foregroundStyle(Color.white)
                    .background(Color(red: 0.35, green: 0.62, blue: 0.50), in: Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text("Quiet Garden")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                Text(ambientAudio.isPlaying ? "Playing relaxing focus music" : "Offline focus music")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Image(systemName: "speaker.fill")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
            Slider(value: $ambientAudio.volume, in: 0...0.8)
                .frame(width: 58)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private var wateringThoughtSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 11) {
                Image(systemName: "waterbottle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(red: 0.23, green: 0.63, blue: 0.82))
                    .frame(width: 42, height: 42)
                    .background(Color.cyan.opacity(0.11), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Water your thoughts")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text("Add an optional thought from this focus session.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            TextEditor(text: $thoughtDraft)
                .font(.system(size: 12))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    if thoughtDraft.isEmpty {
                        Text("What is on your mind?")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }

            HStack {
                Button("Cancel") { showThoughtEditor = false }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    focusStore.completeWatering(thought: thoughtDraft)
                    showThoughtEditor = false
                    performWateringAnimation()
                } label: {
                    Label(thoughtDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Water tree" : "Water & save thought", systemImage: "drop.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.25, green: 0.65, blue: 0.80))
            }
        }
        .padding(22)
        .frame(width: 400, height: 300)
    }

    private func performWateringAnimation() {
        isWatering = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isWatering = false
        }
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
        if focusStore.isBreak {
            if focusStore.isFinished {
                focusStore.startNextWork()
            } else {
                focusStore.toggle()
            }
        } else if focusStore.isFinished && !focusStore.currentTreeClaimed {
            focusStore.claimTree()
        } else if focusStore.isFinished {
            focusStore.startBreak()
        } else {
            focusStore.toggle()
        }
    }

    private var primaryButtonTitle: String {
        if focusStore.isBreak {
            if focusStore.isRunning { return "Pause Break" }
            if focusStore.isFinished { return "Start Next Focus" }
            return "Resume Break"
        }
        if focusStore.isRunning { return "Pause" }
        if focusStore.isFinished && !focusStore.currentTreeClaimed { return "Claim tree" }
        if focusStore.isFinished { return "Start 5 min break" }
        if focusStore.hasStarted { return "Resume Focus" }
        return "Focus"
    }

    private var primaryButtonIcon: String {
        if focusStore.isRunning { return "pause.fill" }
        if focusStore.isFinished && !focusStore.currentTreeClaimed && !focusStore.isBreak { return "gift.fill" }
        if focusStore.isFinished && focusStore.isBreak { return "arrow.right.circle.fill" }
        if focusStore.isFinished { return "cup.and.saucer.fill" }
        return "play.fill"
    }

    private var timerIcon: String {
        if focusStore.isBreak { return focusStore.isFinished ? "checkmark.circle.fill" : "cup.and.saucer.fill" }
        return focusStore.isRunning ? "leaf.fill" : "leaf"
    }

    private var timerTitle: String {
        if focusStore.isBreak {
            if focusStore.isFinished { return "Break complete!" }
            return focusStore.isRunning ? "Break Time" : "Break paused"
        }
        if focusStore.isRunning { return "Stay focused" }
        if focusStore.isFinished { return "Tree complete!" }
        return "Let's focus"
    }

    private var treeMessage: String {
        if focusStore.isBreak && focusStore.isFinished { return "You're recharged" }
        if focusStore.isBreak { return "Take a well-earned break" }
        if focusStore.isFinished && focusStore.currentTreeClaimed { return "Planted in your garden!" }
        if focusStore.isFinished { return "Your tree is in full bloom!" }
        if focusStore.isRunning { return "\(currentTreeDisplayName) is growing" }
        if focusStore.hasStarted { return "\(currentTreeDisplayName) is paused" }
        return "A mystery seed is waiting"
    }

    private var treeSubtitle: String {
        if focusStore.isBreak && focusStore.isFinished { return "Start your next focus session whenever you're ready." }
        if focusStore.isBreak { return "Step away, stretch, and let your mind reset for five minutes." }
        if focusStore.isFinished && focusStore.currentTreeClaimed { return "Take a five-minute break, or skip ahead to your next tree." }
        if focusStore.isFinished { return "Beautiful work. Claim your tree to plant it in the garden." }
        if focusStore.hasStarted { return "Keep the timer running to help your garden flourish." }
        return "Start focusing to discover which tree your seed becomes."
    }

    private var currentTreeName: String {
        ["cherry tree", "golden tree", "lavender tree", "spring tree"][focusStore.currentTreeVariant % 4]
    }

    private var currentTreeDisplayName: String {
        let nickname = focusStore.sessionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return nickname.isEmpty ? "Your \(currentTreeName)" : nickname
    }
}

private struct WateringEffect: View {
    @State private var falling = false

    var body: some View {
        ZStack {
            Image(systemName: "waterbottle.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color(red: 0.29, green: 0.62, blue: 0.76))
                .rotationEffect(.degrees(-52))
                .offset(x: 62, y: -65)

            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .fill(Color.cyan.opacity(0.78))
                    .frame(width: 5, height: 11)
                    .offset(
                        x: CGFloat(index - 4) * 10 + 25,
                        y: falling ? 50 + CGFloat(index % 3) * 8 : -42
                    )
                    .opacity(falling ? 0 : 1)
                    .animation(
                        .easeIn(duration: 0.75).delay(Double(index) * 0.055),
                        value: falling
                    )
            }

            Ellipse()
                .stroke(Color.cyan.opacity(0.55), lineWidth: 2)
                .frame(width: falling ? 100 : 15, height: falling ? 24 : 5)
                .opacity(falling ? 0 : 0.8)
                .offset(y: 72)
                .animation(.easeOut(duration: 1.0).delay(0.45), value: falling)
        }
        .onAppear { falling = true }
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
