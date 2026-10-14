import SwiftUI

enum AppAppearance: String {
    case light, dark

    var colorScheme: ColorScheme { self == .light ? .light : .dark }
}

enum ProgressDisplayStyle: String {
    case ring, segmented
}

extension Color {
    static func appBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.055, green: 0.058, blue: 0.065)
            : Color(red: 0.955, green: 0.96, blue: 0.955)
    }

    static func appCard(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.105, green: 0.11, blue: 0.12)
            : Color.white
    }
}

extension TaskPriority {
    var color: Color {
        switch self {
        case .low: Color(red: 0.45, green: 0.78, blue: 1.0)
        case .medium: Color(red: 1.0, green: 0.76, blue: 0.30)
        case .high: Color(red: 1.0, green: 0.38, blue: 0.40)
        }
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case tasks = "Tasks"
    case projects = "Projects"
    case calendar = "Calendar"
    case focus = "Focus"

    var id: Self { self }
    var icon: String {
        switch self {
        case .tasks: "checkmark.circle"
        case .projects: "square.grid.2x2.fill"
        case .calendar: "calendar"
        case .focus: "leaf.fill"
        }
    }
}

enum TaskFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case open = "Open"
    case done = "Done"

    var id: Self { self }
}

struct ContentView: View {
    @ObservedObject var store: TaskStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appearance") private var appAppearance: AppAppearance = .light
    @AppStorage("progressStyle") private var progressStyle: ProgressDisplayStyle = .ring
    @State private var newTask = ""
    @State private var newProject = "Inbox"
    @State private var newProjectDraft = ""
    @State private var isCreatingProject = false
    @State private var newPriority: TaskPriority = .medium
    @State private var newDueDate = Date.now
    @State private var newLink = ""
    @State private var newLocation = ""
    @State private var selectedTab: AppTab = .tasks
    @State private var filter: TaskFilter = .open
    @State private var selectedProject = "All Projects"
    @State private var showEndDayConfirmation = false
    @State private var endDayMessage: String?
    @State private var editingTask: TaskItem?
    @State private var showCompletedTasks = false
    @FocusState private var isInputFocused: Bool

    private let accent = LinearGradient(
        colors: [Color(red: 0.73, green: 1.0, blue: 0.35), Color(red: 0.27, green: 0.94, blue: 0.84)],
        startPoint: .leading,
        endPoint: .trailing
    )

    private var projects: [String] {
        ["All Projects"] + store.projects
    }

    private var filteredTasks: [TaskItem] {
        let byStatus: [TaskItem]
        switch filter {
        case .all, .open: byStatus = store.tasks.filter { !$0.isCompleted }
        case .done: byStatus = []
        }
        return byStatus
            .filter { selectedProject == "All Projects" || $0.project == selectedProject }
            .sorted {
                let firstDueDay = Calendar.current.startOfDay(for: $0.dueDate)
                let secondDueDay = Calendar.current.startOfDay(for: $1.dueDate)
                if firstDueDay != secondDueDay { return firstDueDay < secondDueDay }
                if $0.priority.rank != $1.priority.rank { return $0.priority.rank > $1.priority.rank }
                return $0.createdAt < $1.createdAt
            }
    }

    private var completedFilteredTasks: [TaskItem] {
        store.tasks
            .filter { $0.isCompleted && (selectedProject == "All Projects" || $0.project == selectedProject) }
            .sorted {
                let firstDueDay = Calendar.current.startOfDay(for: $0.dueDate)
                let secondDueDay = Calendar.current.startOfDay(for: $1.dueDate)
                if firstDueDay != secondDueDay { return firstDueDay < secondDueDay }
                if $0.priority.rank != $1.priority.rank { return $0.priority.rank > $1.priority.rank }
                return $0.createdAt < $1.createdAt
            }
    }

    var body: some View {
        ZStack {
            Color.appBackground(for: colorScheme).ignoresSafeArea()

            Circle()
                .fill(Color.mint.opacity(0.09))
                .frame(width: 440, height: 440)
                .blur(radius: 100)
                .offset(x: 380, y: -280)

            VStack(spacing: 0) {
                header
                switch selectedTab {
                case .tasks:
                    ScrollView {
                        VStack(spacing: 20) {
                            if progressStyle == .ring {
                                progressCard
                            } else {
                                segmentedProgressCard
                            }
                            projectBreakdown
                            addTaskBar
                            taskSection
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 30)
                    }
                case .projects:
                    ProjectsView(store: store)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 30)
                case .calendar:
                    CalendarView(store: store)
                        .padding(.horizontal, 30)
                        .padding(.bottom, 30)
                case .focus:
                    FocusView()
                        .padding(.horizontal, 30)
                        .padding(.bottom, 30)
                }
            }
        }
        .preferredColorScheme(appAppearance.colorScheme)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            store.reloadFromDisk()
        }
        .alert("End the day?", isPresented: $showEndDayConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Tomorrow") {
                let moved = store.endDay()
                withAnimation { endDayMessage = moved == 1 ? "1 task moved to tomorrow" : "\(moved) tasks moved to tomorrow" }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { endDayMessage = nil }
                }
            }
        } message: {
            Text("Every unfinished task due today will be moved to tomorrow. Completed and future tasks will stay where they are.")
        }
        .sheet(item: $editingTask) { task in
            EditTaskSheet(
                task: task,
                projects: projects.filter { $0 != "All Projects" },
                onSave: { store.update($0) }
            )
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(accent)
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.black.opacity(0.78))
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text("Progress")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Text("Make today count")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 2) {
                Button { progressStyle = .ring } label: {
                    Image(systemName: "circle.dashed")
                }
                .buttonStyle(HeaderIconButtonStyle(isSelected: progressStyle == .ring))
                .help("Circular progress")

                Button { progressStyle = .segmented } label: {
                    Image(systemName: "chart.bar.fill")
                }
                .buttonStyle(HeaderIconButtonStyle(isSelected: progressStyle == .segmented))
                .help("Segmented progress")
            }
            .padding(3)
            .background(Color.primary.opacity(0.045), in: Capsule())

            Spacer()

            Picker("Section", selection: $selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()
            .onChange(of: selectedTab) {
                isInputFocused = false
            }

            Spacer()

            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appAppearance = appAppearance == .light ? .dark : .light
                }
            } label: {
                Image(systemName: appAppearance == .light ? "moon.fill" : "sun.max.fill")
                    .frame(width: 29, height: 29)
                    .background(Color.primary.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(appAppearance == .light ? "Switch to dark mode" : "Switch to day mode")
        }
        .padding(.horizontal, 30)
        .padding(.top, 20)
        .padding(.bottom, 18)
    }

    private var progressCard: some View {
        HStack(spacing: 30) {
            progressRing

            VStack(alignment: .leading, spacing: 17) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(progressMessage)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text(store.tasks.isEmpty ? "Add a task to begin your day." : "Every checked task moves you forward.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(store.completedCount) of \(store.tasks.count)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.22, green: 0.72, blue: 0.55))
                    progressStyleButton
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.09))
                        Capsule()
                            .fill(accent)
                            .frame(width: max(store.tasks.isEmpty ? 0 : 8, geometry.size.width * store.progress))
                            .shadow(color: Color.mint.opacity(0.42), radius: 9)
                    }
                }
                .frame(height: 13)
                .animation(.spring(response: 0.5, dampingFraction: 0.82), value: store.progress)

                HStack(spacing: 22) {
                    metric(value: "\(store.remainingCount)", label: "remaining", icon: "circle")
                    metric(value: "\(store.completedCount)", label: "completed", icon: "checkmark.circle.fill")
                }
            }
        }
        .padding(26)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.appCard(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.32 : 0.08), radius: 24, y: 14)
        )
    }

    private var segmentedProgressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("TOTAL PROGRESS", systemImage: "chart.bar.fill")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Spacer()
                progressStyleButton
            }

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text("\(Int((store.progress * 100).rounded()))%")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.15, green: 0.67, blue: 0.43))
                Text("complete")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(store.completedCount) of \(store.tasks.count) tasks")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    HStack(spacing: 5) {
                        ForEach(0..<28, id: \.self) { index in
                            Capsule()
                                .fill(Double(index) / 28 < store.progress ? Color.clear : Color.primary.opacity(0.12))
                                .frame(maxWidth: .infinity)
                        }
                    }

                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(red: 0.05, green: 0.48, blue: 0.30), Color(red: 0.30, green: 0.90, blue: 0.68)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: max(store.tasks.isEmpty ? 0 : 8, geometry.size.width * store.progress))
                        .shadow(color: Color.mint.opacity(0.30), radius: 7)

                    Rectangle()
                        .fill(Color(red: 0.18, green: 0.72, blue: 0.48))
                        .frame(width: 3, height: 30)
                        .offset(x: max(0, min(geometry.size.width - 3, geometry.size.width * store.progress - 1.5)))
                }
            }
            .frame(height: 20)
            .animation(.spring(response: 0.5, dampingFraction: 0.82), value: store.progress)

            HStack {
                Text("\(store.remainingCount) remaining")
                Spacer()
                Text("\(store.completedCount) completed")
                Image(systemName: "chevron.right")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(Color.primary.opacity(0.04), in: Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.08)))
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.appCard(for: colorScheme))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.primary.opacity(0.08)))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 22, y: 10)
        )
    }

    private var progressStyleButton: some View {
        Menu {
            Button { progressStyle = .ring } label: {
                Label("Circular progress", systemImage: progressStyle == .ring ? "checkmark" : "circle.dashed")
            }
            Button { progressStyle = .segmented } label: {
                Label("Segmented progress", systemImage: progressStyle == .segmented ? "checkmark" : "chart.bar.fill")
            }
        } label: {
            Label(
                progressStyle == .ring ? "Circular" : "Segmented",
                systemImage: progressStyle == .ring ? "circle.dashed" : "chart.bar.fill"
            )
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Color.primary.opacity(0.055), in: Capsule())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Choose progress bar style")
    }

    private var projectBreakdown: some View {
        let groups = Dictionary(grouping: store.tasks, by: \.project)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PROJECT BREAKDOWN")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(groups.count) projects")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if groups.isEmpty {
                Text("Projects will appear here when you add tasks.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                    ForEach(groups.keys.sorted(), id: \.self) { project in
                        ProjectProgressCard(project: project, tasks: groups[project] ?? [])
                    }
                }
            }
        }
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.075), style: StrokeStyle(lineWidth: 13, lineCap: .round))
            Circle()
                .trim(from: 0, to: max(store.tasks.isEmpty ? 0 : 0.015, store.progress))
                .stroke(accent, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.mint.opacity(0.4), radius: 8)
                .animation(.spring(response: 0.55, dampingFraction: 0.78), value: store.progress)

            VStack(spacing: 0) {
                Text("\(Int((store.progress * 100).rounded()))")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text("PERCENT")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 132, height: 132)
        .padding(4)
    }

    private func metric(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .foregroundStyle(Color(red: 0.50, green: 0.96, blue: 0.76))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var addTaskBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(red: 0.48, green: 0.96, blue: 0.75))

                TextField("What would you like to get done?", text: $newTask)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .focused($isInputFocused)
                    .onSubmit(addTask)

                Text("↵")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))

                Button("Add") { addTask() }
                    .buttonStyle(AccentButtonStyle())
                    .disabled(newTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Divider().opacity(0.35)

            HStack(spacing: 16) {
                Label("Project", systemImage: "folder")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Menu {
                    ForEach(projects.filter { $0 != "All Projects" }, id: \.self) { project in
                        Button {
                            newProject = project
                            isCreatingProject = false
                        } label: {
                            if project == newProject {
                                Label(project, systemImage: "checkmark")
                            } else {
                                Text(project)
                            }
                        }
                    }
                    Divider()
                    Button {
                        newProjectDraft = ""
                        isCreatingProject = true
                    } label: {
                        Label("New Project…", systemImage: "plus")
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(newProject)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                if isCreatingProject {
                    HStack(spacing: 4) {
                        TextField("New project", text: $newProjectDraft)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 110)
                            .onSubmit(createProject)
                        Button(action: createProject) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.green)
                        }
                        .buttonStyle(.plain)
                        .disabled(newProjectDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button {
                            isCreatingProject = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
                }

                Spacer()

                Label("Priority", systemImage: "flag")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Picker("Priority", selection: $newPriority) {
                    ForEach(TaskPriority.allCases) { priority in
                        Text(priority.rawValue).tag(priority)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 90)

                DatePicker("Due", selection: $newDueDate, displayedComponents: .date)
                    .font(.system(size: 11, weight: .semibold))
                    .datePickerStyle(.compact)
                    .fixedSize()
            }
            .padding(.horizontal, 7)

            Divider().opacity(0.25)

            HStack(spacing: 14) {
                Label("Link", systemImage: "link")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("Website or meeting link (optional)", text: $newLink)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .medium))

                Divider().frame(height: 18)

                Label("Location", systemImage: "mappin.and.ellipse")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("Place or address (optional)", text: $newLocation)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 7)
        }
        .padding(.leading, 17)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 17)
                .fill(Color.primary.opacity(0.045))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.primary.opacity(0.08)))
        )
    }

    private var taskSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("MY TASKS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    ForEach(projects, id: \.self) { project in
                        Button {
                            selectedProject = project
                        } label: {
                            if project == selectedProject {
                                Label(project, systemImage: "checkmark")
                            } else {
                                Text(project)
                            }
                        }
                    }
                } label: {
                    Label(selectedProject, systemImage: "folder")
                        .font(.system(size: 10, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                HStack(spacing: 2) {
                    ForEach(TaskFilter.allCases) { option in
                        Button(option.rawValue) {
                            filter = option
                            showCompletedTasks = false
                        }
                        .buttonStyle(FilterButtonStyle(isSelected: filter == option))
                    }
                }

                if let endDayMessage {
                    Label(endDayMessage, systemImage: "arrow.right.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.green)
                        .transition(.opacity)
                }

                Button {
                    showEndDayConfirmation = true
                } label: {
                    Label("End day", systemImage: "moon.stars.fill")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(store.openTasksDueTodayCount == 0)
                .help(store.openTasksDueTodayCount == 0 ? "No unfinished tasks due today" : "Move today's unfinished tasks to tomorrow")

                if store.completedCount > 0 {
                    Button("Clear done") { withAnimation { store.clearCompleted() } }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
            }

            if filteredTasks.isEmpty && (filter != .done || completedFilteredTasks.isEmpty) {
                emptyState
            } else if !filteredTasks.isEmpty {
                LazyVStack(spacing: 8) {
                    ForEach(filteredTasks) { task in
                        taskRow(task)
                    }
                }
            }

            if !completedFilteredTasks.isEmpty {
                completedTasksDisclosure
            }
        }
    }

    private var completedTasksDisclosure: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                    showCompletedTasks.toggle()
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(showCompletedTasks ? 90 : 0))
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(red: 0.38, green: 0.78, blue: 0.58))
                    Text("Completed")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    Text("\(completedFilteredTasks.count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                    Spacer()
                    Text(showCompletedTasks ? "Collapse" : "Show tasks")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 13))

            if showCompletedTasks {
                LazyVStack(spacing: 8) {
                    ForEach(completedFilteredTasks) { task in
                        taskRow(task)
                    }
                }
            }
        }
    }

    private func taskRow(_ task: TaskItem) -> some View {
        TaskRow(
            task: task,
            onToggle: { withAnimation { store.toggle(task) } },
            onEdit: { editingTask = task },
            onDelete: { withAnimation { store.delete(task) } }
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var emptyState: some View {
        VStack(spacing: 9) {
            Image(systemName: filter == .done ? "checkmark.circle" : "sparkles")
                .font(.system(size: 25, weight: .light))
                .foregroundStyle(Color.mint.opacity(0.75))
            Text(filter == .done ? "No completed tasks yet" : filter == .open ? "You're all caught up" : "Your list is ready")
                .font(.system(size: 14, weight: .semibold))
            Text(filter == .all ? "Add your first task above." : "Choose another filter to see your tasks.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 18))
    }

    private var progressMessage: String {
        if store.tasks.isEmpty { return "Ready when you are" }
        if store.progress == 1 { return "Beautiful work!" }
        if store.progress >= 0.5 { return "You're on a roll" }
        return "Small steps, big progress"
    }

    private func createProject() {
        let cleaned = newProjectDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        newProject = String(cleaned.prefix(100))
        newProjectDraft = ""
        isCreatingProject = false
    }

    private func addTask() {
        guard !newTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            store.add(
                newTask,
                project: newProject,
                priority: newPriority,
                dueDate: newDueDate,
                link: newLink,
                location: newLocation
            )
            newTask = ""
            newLink = ""
            newLocation = ""
            filter = .open
        }
        isInputFocused = true
    }
}

private struct ProjectProgressCard: View {
    let project: String
    let tasks: [TaskItem]
    @Environment(\.colorScheme) private var colorScheme

    private var completed: Int { tasks.filter(\.isCompleted).count }
    private var open: Int { tasks.count - completed }
    private var progress: Double { tasks.isEmpty ? 0 : Double(completed) / Double(tasks.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Label(project, systemImage: "folder.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text("Overall project progress")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.18, green: 0.72, blue: 0.52))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(red: 0.05, green: 0.48, blue: 0.30), Color(red: 0.30, green: 0.90, blue: 0.68)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: max(tasks.isEmpty ? 0 : 7, geometry.size.width * progress))
                }
            }
            .frame(height: 11)

            HStack(spacing: 8) {
                projectMetric("Total", value: tasks.count, icon: "list.bullet", color: .blue)
                projectMetric("Completed", value: completed, icon: "checkmark.circle.fill", color: .green)
                projectMetric("Open", value: open, icon: "circle.dashed", color: .orange)
            }
        }
        .padding(17)
        .background(
            RoundedRectangle(cornerRadius: 19)
                .fill(Color.appCard(for: colorScheme))
                .overlay(RoundedRectangle(cornerRadius: 19).stroke(Color.primary.opacity(0.075)))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.06), radius: 14, y: 6)
        )
    }

    private func projectMetric(_ label: String, value: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text(label)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct EditTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var task: TaskItem
    let projects: [String]
    let onSave: (TaskItem) -> Void

    init(task: TaskItem, projects: [String], onSave: @escaping (TaskItem) -> Void) {
        _task = State(initialValue: task)
        self.projects = projects
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Edit task")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("Update the task details, schedule, and status.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .frame(width: 26, height: 26)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 7) {
                fieldLabel("Task name", icon: "checkmark.circle")
                TextField("Task name", text: $task.title)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, weight: .medium))
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    fieldLabel("Project", icon: "folder")
                    HStack(spacing: 6) {
                        TextField("Project", text: $task.project)
                            .textFieldStyle(.roundedBorder)
                        Menu {
                            ForEach(projects, id: \.self) { project in
                                Button(project) { task.project = project }
                            }
                        } label: {
                            Image(systemName: "chevron.down")
                                .frame(width: 24, height: 22)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                }

                VStack(alignment: .leading, spacing: 7) {
                    fieldLabel("Priority", icon: "flag")
                    Picker("Priority", selection: $task.priority) {
                        ForEach(TaskPriority.allCases) { priority in
                            Text(priority.rawValue).tag(priority)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
            }

            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    fieldLabel("Due date", icon: "calendar")
                    DatePicker("Due date", selection: $task.dueDate, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
                Spacer()
                Toggle(isOn: $task.isCompleted) {
                    Label(task.isCompleted ? "Completed" : "Open", systemImage: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 11, weight: .semibold))
                }
                .toggleStyle(.switch)
            }

            VStack(alignment: .leading, spacing: 7) {
                fieldLabel("Link", icon: "link")
                TextField("Website or meeting link", text: Binding(
                    get: { task.link ?? "" },
                    set: { task.link = $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 7) {
                fieldLabel("Location", icon: "mappin.and.ellipse")
                TextField("Place or address", text: Binding(
                    get: { task.location ?? "" },
                    set: { task.location = $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }

            HStack {
                Text("Created \(task.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save Changes") {
                    onSave(task)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.24, green: 0.70, blue: 0.48))
                .keyboardShortcut(.defaultAction)
                .disabled(task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 500, height: 520)
    }

    private func fieldLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)
    }
}

private struct TaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 13) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .stroke(task.isCompleted ? Color.clear : Color.primary.opacity(0.32), lineWidth: 1.7)
                        .background(Circle().fill(task.isCompleted ? Color(red: 0.45, green: 0.94, blue: 0.70) : .clear))
                    if task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Color.black.opacity(0.8))
                    }
                }
                .frame(width: 21, height: 21)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help(task.isCompleted ? "Mark as open" : "Mark as completed")

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted, color: .secondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Label(task.project, systemImage: "folder.fill")
                    Text(task.priority.rawValue)
                        .foregroundStyle(task.priority.color)
                    Text(task.dueDate.formatted(.dateTime.month(.abbreviated).day()))
                    Text(task.isCompleted ? "Completed" : "Added \(task.createdAt.formatted(.relative(presentation: .named)))")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)

                if task.link != nil || task.location != nil {
                    HStack(spacing: 10) {
                        if let link = task.link, let url = URL(string: link) {
                            Link(destination: url) {
                                Label("Open link", systemImage: "arrow.up.right.square")
                            }
                            .help(link)
                        }
                        if let location = task.location, let url = mapsURL(for: location) {
                            Link(destination: url) {
                                Label(location, systemImage: "mappin.and.ellipse")
                                    .lineLimit(1)
                            }
                            .help("Open in Maps")
                        }
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(red: 0.20, green: 0.62, blue: 0.72))
                }
            }

            Spacer()

            if isHovered {
                HStack(spacing: 5) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.primary.opacity(0.055), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Edit task")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Color.primary.opacity(0.055), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Delete task")
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.primary.opacity(isHovered ? 0.065 : 0.04))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.primary.opacity(isHovered ? 0.1 : 0.055)))
        )
        .contentShape(Rectangle())
        .onHover { hovering in withAnimation(.easeOut(duration: 0.14)) { isHovered = hovering } }
        .contextMenu {
            Button(task.isCompleted ? "Mark as Open" : "Mark as Done", action: onToggle)
            Button("Edit Task…", systemImage: "pencil", action: onEdit)
            if let link = task.link, let url = URL(string: link) {
                Link("Open Link", destination: url)
            }
            if let location = task.location, let url = mapsURL(for: location) {
                Link("Open Location in Maps", destination: url)
            }
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    private func mapsURL(for location: String) -> URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "q", value: location)]
        return components?.url
    }
}

private struct HeaderIconButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isSelected ? Color.black.opacity(0.78) : Color.secondary)
            .frame(width: 27, height: 24)
            .background(
                isSelected
                    ? Color(red: 0.47, green: 0.94, blue: 0.68)
                    : Color.clear,
                in: Capsule()
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Color.black.opacity(0.8))
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .background(
                LinearGradient(colors: [Color(red: 0.73, green: 1, blue: 0.35), Color(red: 0.28, green: 0.94, blue: 0.83)], startPoint: .leading, endPoint: .trailing),
                in: Capsule()
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

private struct FilterButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.primary.opacity(0.1) : Color.clear, in: Capsule())
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}
