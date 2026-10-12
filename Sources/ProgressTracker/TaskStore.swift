import Combine
import Foundation

@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var tasks: [TaskItem] = []
    @Published private(set) var events: [CalendarEvent] = []

    private let saveURL: URL
    private let eventsURL: URL

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProgressTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        saveURL = directory.appendingPathComponent("tasks.json")
        eventsURL = directory.appendingPathComponent("events.json")
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

    func add(_ title: String, project: String, priority: TaskPriority, dueDate: Date) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedProject = project.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        reloadFromDisk()
        tasks.insert(TaskItem(
            title: cleaned,
            project: cleanedProject.isEmpty ? "Inbox" : cleanedProject,
            priority: priority,
            dueDate: dueDate
        ), at: 0)
        save()
    }

    func toggle(_ task: TaskItem) {
        reloadFromDisk()
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isCompleted.toggle()
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

    func addEvent(
        _ title: String,
        at date: Date,
        recurrence: EventRecurrence = .none,
        weekdays: [Int] = []
    ) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        reloadFromDisk()
        events.append(CalendarEvent(
            title: cleaned,
            startDate: date,
            recurrence: recurrence,
            recurrenceWeekdays: weekdays.sorted()
        ))
        events.sort { $0.startDate < $1.startDate }
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
        if let data = try? Data(contentsOf: eventsURL),
           let stored = try? JSONDecoder().decode([CalendarEvent].self, from: data),
           stored != events {
            events = stored
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }

    private func saveEvents() {
        guard let data = try? JSONEncoder().encode(events) else { return }
        try? data.write(to: eventsURL, options: .atomic)
    }
}
