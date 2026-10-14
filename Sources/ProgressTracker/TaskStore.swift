import Combine
import Foundation

@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var projects: [String] = ["Inbox"]

    private let saveURL: URL
    private let eventsURL: URL
    private let projectsURL: URL

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProgressTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        saveURL = directory.appendingPathComponent("tasks.json")
        eventsURL = directory.appendingPathComponent("events.json")
        projectsURL = directory.appendingPathComponent("projects.json")
        reloadFromDisk()

        if tasks.isEmpty && !FileManager.default.fileExists(atPath: saveURL.path) {
            tasks = [
                TaskItem(title: "Sketch the first idea", isCompleted: true, project: "Launch", priority: .medium),
                TaskItem(title: "Plan this week's priorities", isCompleted: true, project: "Personal", priority: .high),
                TaskItem(title: "Ship something meaningful", project: "Launch", priority: .high)
            ]
            save()
        }
    }

    var completedCount: Int { tasks.filter(\.isCompleted).count }
    var remainingCount: Int { tasks.count - completedCount }
    var progress: Double { tasks.isEmpty ? 0 : Double(completedCount) / Double(tasks.count) }
    var openTasksDueTodayCount: Int {
        tasks.filter { !$0.isCompleted && Calendar.current.isDateInToday($0.dueDate) }.count
    }

    func add(
        _ title: String,
        project: String,
        priority: TaskPriority,
        dueDate: Date,
        link: String? = nil,
        location: String? = nil
    ) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedProject = project.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedLink = link?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedLocation = location?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        reloadFromDisk()
        let projectName = cleanedProject.isEmpty ? "Inbox" : cleanedProject
        if !projects.contains(where: { $0.caseInsensitiveCompare(projectName) == .orderedSame }) {
            projects.append(projectName)
            projects.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            saveProjects()
        }
        tasks.insert(TaskItem(
            title: cleaned,
            project: projectName,
            priority: priority,
            dueDate: dueDate,
            link: cleanedLink?.isEmpty == false ? normalizedLink(cleanedLink!) : nil,
            location: cleanedLocation?.isEmpty == false ? cleanedLocation : nil
        ), at: 0)
        save()
    }

    func addProject(_ name: String) {
        let cleaned = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
        guard !cleaned.isEmpty,
              !projects.contains(where: { $0.caseInsensitiveCompare(cleaned) == .orderedSame }) else { return }
        projects.append(cleaned)
        projects.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        saveProjects()
    }

    func moveTask(id: UUID, toProject project: String) {
        reloadFromDisk()
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        addProject(project)
        tasks[index].project = project
        save()
    }

    func toggle(_ task: TaskItem) {
        reloadFromDisk()
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isCompleted.toggle()
        save()
    }

    func update(_ task: TaskItem) {
        reloadFromDisk()
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var updated = task
        updated.title = updated.title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.project = updated.project.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.link = updated.link?.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.location = updated.location?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !updated.title.isEmpty else { return }
        if updated.project.isEmpty { updated.project = "Inbox" }
        addProject(updated.project)
        if let link = updated.link, !link.isEmpty {
            updated.link = normalizedLink(link)
        } else {
            updated.link = nil
        }
        if updated.location?.isEmpty == true { updated.location = nil }
        tasks[index] = updated
        save()
    }

    func delete(_ task: TaskItem) {
        reloadFromDisk()
        tasks.removeAll { $0.id == task.id }
        save()
    }

    func clearCompleted() {
        reloadFromDisk()
        tasks.removeAll(where: \.isCompleted)
        save()
    }

    /// Closes out today by carrying every unfinished task due today to tomorrow.
    @discardableResult
    func endDay() -> Int {
        reloadFromDisk()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else { return 0 }
        var movedCount = 0

        for index in tasks.indices where !tasks[index].isCompleted {
            let taskDay = calendar.startOfDay(for: tasks[index].dueDate)
            guard taskDay <= startOfToday else { continue }
            tasks[index].dueDate = date(on: startOfTomorrow, preservingTimeFrom: tasks[index].dueDate)
            movedCount += 1
        }

        if movedCount > 0 { save() }
        return movedCount
    }

    @discardableResult
    func addEvent(
        _ title: String,
        at date: Date,
        recurrence: EventRecurrence = .none,
        weekdays: [Int] = []
    ) -> CalendarEvent? {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        reloadFromDisk()
        let event = CalendarEvent(
            title: cleaned,
            startDate: date,
            recurrence: recurrence,
            recurrenceWeekdays: weekdays.sorted()
        )
        events.append(event)
        events.sort { $0.startDate < $1.startDate }
        saveEvents()
        return event
    }

    func linkEvent(_ eventID: UUID, toExternalIdentifier identifier: String) {
        guard let index = events.firstIndex(where: { $0.id == eventID }) else { return }
        events[index].externalEventIdentifier = identifier
        saveEvents()
    }

    func deleteEvent(_ event: CalendarEvent) {
        reloadFromDisk()
        events.removeAll { $0.id == event.id }
        saveEvents()
    }

    func tasks(on date: Date) -> [TaskItem] {
        tasks.filter { Calendar.current.isDate($0.dueDate, inSameDayAs: date) }
            .sorted {
                if $0.isCompleted != $1.isCompleted { return !$0.isCompleted }
                return $0.priority.rank > $1.priority.rank
            }
    }

    func events(on date: Date) -> [CalendarEvent] {
        events.filter { $0.occurs(on: date) }
            .sorted { $0.startDate < $1.startDate }
    }

    func reloadFromDisk() {
        if let data = try? Data(contentsOf: saveURL),
           let stored = try? JSONDecoder().decode([TaskItem].self, from: data),
           stored != tasks {
            tasks = stored
        }
        // If the date changed while the app was closed (or at midnight), unfinished
        // overdue tasks automatically become today's tasks.
        if carryOverdueTasksToToday() { save() }

        if let data = try? Data(contentsOf: eventsURL),
           let stored = try? JSONDecoder().decode([CalendarEvent].self, from: data),
           stored != events {
            events = stored
        }
        if let data = try? Data(contentsOf: projectsURL),
           let stored = try? JSONDecoder().decode([String].self, from: data) {
            projects = stored
        }
        let discoveredProjects = Set(tasks.map(\.project) + ["Inbox"])
        var projectsChanged = false
        for project in discoveredProjects where !projects.contains(project) {
            projects.append(project)
            projectsChanged = true
        }
        projects.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        if projectsChanged { saveProjects() }
    }

    private func normalizedLink(_ link: String) -> String {
        guard URL(string: link)?.scheme == nil else { return link }
        return "https://\(link)"
    }

    private func carryOverdueTasksToToday() -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var changed = false

        for index in tasks.indices where !tasks[index].isCompleted {
            guard calendar.startOfDay(for: tasks[index].dueDate) < today else { continue }
            tasks[index].dueDate = date(on: today, preservingTimeFrom: tasks[index].dueDate)
            changed = true
        }
        return changed
    }

    private func date(on day: Date, preservingTimeFrom original: Date) -> Date {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute, .second], from: original)
        return calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: time.second ?? 0, of: day) ?? day
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }

    private func saveEvents() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        try? data.write(to: eventsURL, options: .atomic)
    }

    private func saveProjects() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        try? data.write(to: projectsURL, options: .atomic)
    }
}
