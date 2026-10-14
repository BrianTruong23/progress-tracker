import SwiftUI

struct ProjectsView: View {
    @ObservedObject var store: TaskStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var newProjectName = ""

    var body: some View {
        VStack(spacing: 14) {
            projectHeader

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(Array(store.projects.enumerated()), id: \.element) { index, project in
                        ProjectBoardColumn(
                            project: project,
                            tasks: tasks(in: project),
                            tint: projectColor(index),
                            onToggle: store.toggle,
                            onDropTask: { id in
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    store.moveTask(id: id, toProject: project)
                                }
                            }
                        )
                    }
                }
                .padding(2)
            }
            .scrollIndicators(.visible)
        }
    }

    private var projectHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Project board")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("Drag tasks between columns to reorganize your work.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "folder.badge.plus")
                    .foregroundStyle(Color(red: 0.26, green: 0.70, blue: 0.53))
                TextField("New project name", text: $newProjectName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 155)
                    .onSubmit(addProject)
                Button("Add Project", action: addProject)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(Color(red: 0.28, green: 0.70, blue: 0.49))
                    .disabled(newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.primary.opacity(0.045), in: Capsule())
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 21)
                .fill(Color.appCard(for: colorScheme))
                .overlay(RoundedRectangle(cornerRadius: 21).stroke(Color.primary.opacity(0.075)))
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.20 : 0.055), radius: 13, y: 6)
        )
    }

    private func tasks(in project: String) -> [TaskItem] {
        store.tasks
            .filter { $0.project == project && !$0.isCompleted }
            .sorted {
                let firstDueDay = Calendar.current.startOfDay(for: $0.dueDate)
                let secondDueDay = Calendar.current.startOfDay(for: $1.dueDate)
                if firstDueDay != secondDueDay { return firstDueDay < secondDueDay }
                if $0.priority.rank != $1.priority.rank { return $0.priority.rank > $1.priority.rank }
                return $0.createdAt < $1.createdAt
            }
    }

    private func addProject() {
        let cleaned = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            store.addProject(cleaned)
            newProjectName = ""
        }
    }

    private func projectColor(_ index: Int) -> Color {
        let colors: [Color] = [
            Color(red: 0.29, green: 0.72, blue: 0.53),
            Color(red: 0.35, green: 0.62, blue: 0.91),
            Color(red: 0.72, green: 0.52, blue: 0.91),
            Color(red: 0.94, green: 0.60, blue: 0.30),
            Color(red: 0.90, green: 0.43, blue: 0.55)
        ]
        return colors[index % colors.count]
    }
}

private struct ProjectBoardColumn: View {
    let project: String
    let tasks: [TaskItem]
    let tint: Color
    let onToggle: (TaskItem) -> Void
    let onDropTask: (UUID) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isDropTarget = false

    var body: some View {
        VStack(spacing: 11) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(tint.opacity(0.15))
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 1) {
                    Text(project)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    Text("\(tasks.count) open task\(tasks.count == 1 ? "" : "s")")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider().opacity(0.35)

            ScrollView {
                LazyVStack(spacing: 8) {
                    if tasks.isEmpty {
                        VStack(spacing: 7) {
                            Image(systemName: isDropTarget ? "arrow.down.circle.fill" : "tray")
                                .font(.system(size: 24, weight: .light))
                                .foregroundStyle(isDropTarget ? tint : Color.secondary.opacity(0.55))
                            Text(isDropTarget ? "Drop task here" : "No tasks yet")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Drag a task into this project")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 34)
                    } else {
                        ForEach(tasks) { task in
                            projectTaskCard(task)
                                .draggable(task.id.uuidString) {
                                    HStack(spacing: 7) {
                                        Image(systemName: "checkmark.circle")
                                        Text(task.title).lineLimit(1)
                                    }
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(10)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                                }
                        }
                    }
                }
                .padding(1)
            }
        }
        .padding(13)
        .frame(width: 245)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(isDropTarget ? tint.opacity(0.10) : Color.appCard(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(isDropTarget ? tint : Color.primary.opacity(0.07), lineWidth: isDropTarget ? 2 : 1)
                )
        )
        .dropDestination(for: String.self) { values, _ in
            guard let value = values.first, let id = UUID(uuidString: value) else { return false }
            onDropTask(id)
            return true
        } isTargeted: { targeted in
            withAnimation(.easeOut(duration: 0.16)) { isDropTarget = targeted }
        }
    }

    private func projectTaskCard(_ task: TaskItem) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Button { onToggle(task) } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(task.isCompleted ? tint : Color.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.system(size: 11, weight: .semibold))
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Label(task.priority.rawValue, systemImage: "flag.fill")
                        .foregroundStyle(task.priority.color)
                    Label(task.dueDate.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                }
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(.secondary)

                if let location = task.location, !location.isEmpty {
                    Label(location, systemImage: "mappin")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.055)))
        .contentShape(Rectangle())
    }
}
