import Combine
import Foundation

struct PlantedTree: Codable, Identifiable, Equatable {
    let id: UUID
    let plantedAt: Date
    let focusMinutes: Int
    let variant: Int

    var name: String {
        ["Cherry Bloom", "Golden Bloom", "Lavender Bloom", "Spring Bloom"][variant % 4]
    }
}

private struct StoredFocusSession: Codable {
    var selectedMinutes: Int
    var remainingSeconds: Int
    var isRunning: Bool
    var endDate: Date?
    var hasStarted: Bool
    var isFinished: Bool
    var completedSessions: Int
    // Optional so existing focus.json files migrate without losing progress.
    var plantedTrees: [PlantedTree]?
    var currentTreeClaimed: Bool?
    var activeTreeVariant: Int?
}

@MainActor
final class FocusSessionStore: ObservableObject {
    @Published private(set) var selectedMinutes = 25
    @Published private(set) var remainingSeconds = 25 * 60
    @Published private(set) var isRunning = false
    @Published private(set) var hasStarted = false
    @Published private(set) var isFinished = false
    @Published private(set) var completedSessions = 0
    @Published private(set) var plantedTrees: [PlantedTree] = []
    @Published private(set) var currentTreeClaimed = false
    @Published private(set) var activeTreeVariant = 0

    private var endDate: Date?
    private let saveURL: URL

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProgressTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        saveURL = directory.appendingPathComponent("focus.json")
        reloadFromDisk()
    }

    var totalSeconds: Int { selectedMinutes * 60 }
    var currentTreeVariant: Int { activeTreeVariant }
    var progress: Double {
        guard hasStarted else { return 0 }
        return min(1, max(0, 1 - Double(remainingSeconds) / Double(totalSeconds)))
    }

    func setDuration(minutes: Int) {
        guard !hasStarted, [15, 25, 45].contains(minutes) else { return }
        selectedMinutes = minutes
        remainingSeconds = totalSeconds
        save()
    }

    func toggle() {
        reloadFromDisk()
        if isFinished {
            guard currentTreeClaimed else { return }
            reset(saveAfter: false)
            begin()
        } else if isRunning {
            pause()
        } else {
            begin()
        }
    }

    func start(minutes: Int? = nil) {
        reloadFromDisk()
        if let minutes, [15, 25, 45].contains(minutes) {
            selectedMinutes = minutes
        }
        remainingSeconds = totalSeconds
        hasStarted = true
        isFinished = false
        activeTreeVariant = Int.random(in: 0..<4)
        currentTreeClaimed = false
        isRunning = true
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        save()
    }

    func pause() {
        guard isRunning else { return }
        updateRemainingTime()
        isRunning = false
        endDate = nil
        save()
    }

    func resume() {
        reloadFromDisk()
        guard hasStarted, !isFinished, !isRunning, remainingSeconds > 0 else { return }
        isRunning = true
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        save()
    }

    func reset() {
        reset(saveAfter: true)
    }

    func claimTree() {
        reloadFromDisk()
        guard isFinished, !currentTreeClaimed else { return }
        plantedTrees.append(PlantedTree(
            id: UUID(),
            plantedAt: Date(),
            focusMinutes: selectedMinutes,
            variant: currentTreeVariant
        ))
        currentTreeClaimed = true
        save()
    }

    func tick() {
        reloadFromDisk()
        guard isRunning else { return }
        updateRemainingTime()
        if remainingSeconds == 0 {
            isRunning = false
            endDate = nil
            isFinished = true
            currentTreeClaimed = false
            completedSessions += 1
        }
        save()
    }

    func reloadFromDisk() {
        guard let data = try? Data(contentsOf: saveURL),
              let stored = try? JSONDecoder().decode(StoredFocusSession.self, from: data) else { return }
        selectedMinutes = stored.selectedMinutes
        remainingSeconds = stored.remainingSeconds
        isRunning = stored.isRunning
        endDate = stored.endDate
        hasStarted = stored.hasStarted
        isFinished = stored.isFinished
        completedSessions = stored.completedSessions
        plantedTrees = stored.plantedTrees ?? []
        // Sessions completed before collections were added remain claimable.
        currentTreeClaimed = stored.currentTreeClaimed ?? !stored.isFinished
        activeTreeVariant = stored.activeTreeVariant ?? max(0, stored.completedSessions - (stored.isFinished ? 1 : 0)) % 4
        if isRunning { updateRemainingTime() }
    }

    private func begin() {
        if !hasStarted {
            activeTreeVariant = Int.random(in: 0..<4)
        }
        hasStarted = true
        isRunning = true
        isFinished = false
        currentTreeClaimed = false
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        save()
    }

    private func updateRemainingTime() {
        guard let endDate else { return }
        remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
    }

    private func reset(saveAfter: Bool) {
        isRunning = false
        endDate = nil
        hasStarted = false
        isFinished = false
        currentTreeClaimed = false
        remainingSeconds = totalSeconds
        if saveAfter { save() }
    }

    private func save() {
        let stored = StoredFocusSession(
            selectedMinutes: selectedMinutes,
            remainingSeconds: remainingSeconds,
            isRunning: isRunning,
            endDate: endDate,
            hasStarted: hasStarted,
            isFinished: isFinished,
            completedSessions: completedSessions,
            plantedTrees: plantedTrees,
            currentTreeClaimed: currentTreeClaimed,
            activeTreeVariant: activeTreeVariant
        )
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }
}
