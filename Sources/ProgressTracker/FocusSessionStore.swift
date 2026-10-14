import AppKit
import Combine
import Foundation

enum FocusPhase: String, Codable {
    case work
    case breakTime
}

struct PlantedTree: Codable, Identifiable, Equatable {
    let id: UUID
    let plantedAt: Date
    let focusMinutes: Int
    let variant: Int
    let sessionName: String?
    let thoughts: [String]?

    var name: String {
        ["Cherry Bloom", "Golden Bloom", "Lavender Bloom", "Spring Bloom"][variant % 4]
    }

    var nickname: String {
        guard let sessionName = sessionName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !sessionName.isEmpty else { return name }
        return sessionName
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
    var phase: FocusPhase?
    var totalWaterings: Int?
    var sessionName: String?
    var sessionThoughts: [String]?
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
    @Published private(set) var phase: FocusPhase = .work
    @Published private(set) var totalWaterings = 0
    @Published private(set) var sessionName = ""
    @Published private(set) var sessionThoughts: [String] = []

    private var endDate: Date?
    private let saveURL: URL

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProgressTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        saveURL = directory.appendingPathComponent("focus.json")
        reloadFromDisk()
    }

    var totalSeconds: Int { phase == .breakTime ? 5 * 60 : selectedMinutes * 60 }
    var currentTreeVariant: Int { activeTreeVariant }
    var isBreak: Bool { phase == .breakTime }
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
            if phase == .breakTime {
                startNextWork()
                return
            }
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
        phase = .work
        if let minutes, [15, 25, 45].contains(minutes) {
            selectedMinutes = minutes
        }
        remainingSeconds = totalSeconds
        hasStarted = true
        isFinished = false
        activeTreeVariant = Int.random(in: 0..<4)
        sessionName = ""
        sessionThoughts = []
        currentTreeClaimed = false
        isRunning = true
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        save()
    }

    func startBreak() {
        reloadFromDisk()
        guard phase == .work, isFinished, currentTreeClaimed else { return }
        phase = .breakTime
        remainingSeconds = 5 * 60
        hasStarted = true
        isFinished = false
        isRunning = true
        endDate = Date().addingTimeInterval(5 * 60)
        save()
    }

    func startNextWork() {
        phase = .work
        reset(saveAfter: false)
        begin()
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

    func setSessionName(_ name: String) {
        sessionName = String(name.prefix(80))
        save()
    }

    func completeWatering(thought: String) {
        totalWaterings += 1
        let trimmed = thought.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            sessionThoughts.append(String(trimmed.prefix(500)))
        }
        save()
    }

    func claimTree() {
        reloadFromDisk()
        guard phase == .work, isFinished, !currentTreeClaimed else { return }
        plantedTrees.append(PlantedTree(
            id: UUID(),
            plantedAt: Date(),
            focusMinutes: selectedMinutes,
            variant: currentTreeVariant,
            sessionName: sessionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : sessionName,
            thoughts: sessionThoughts.isEmpty ? nil : sessionThoughts
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
            if phase == .work {
                currentTreeClaimed = false
                completedSessions += 1
            }
            playCompletionSound()
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
        phase = stored.phase ?? .work
        totalWaterings = stored.totalWaterings ?? 0
        sessionName = stored.sessionName ?? ""
        sessionThoughts = stored.sessionThoughts ?? []
        if isRunning { updateRemainingTime() }
    }

    private func begin() {
        if !hasStarted && phase == .work {
            activeTreeVariant = Int.random(in: 0..<4)
        }
        hasStarted = true
        isRunning = true
        isFinished = false
        if phase == .work {
            currentTreeClaimed = false
        }
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        save()
    }

    private func updateRemainingTime() {
        guard let endDate else { return }
        remainingSeconds = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
    }

    private func playCompletionSound() {
        // Use a distinct chime so it is easy to tell work and rest endings apart.
        let soundName = phase == .breakTime ? "Ping" : "Glass"
        if let sound = NSSound(named: NSSound.Name(soundName)) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func reset(saveAfter: Bool) {
        isRunning = false
        endDate = nil
        hasStarted = false
        isFinished = false
        currentTreeClaimed = false
        if phase == .work {
            sessionName = ""
            sessionThoughts = []
        }
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
            activeTreeVariant: activeTreeVariant,
            phase: phase,
            totalWaterings: totalWaterings,
            sessionName: sessionName,
            sessionThoughts: sessionThoughts
        )
        guard let data = try? JSONEncoder().encode(stored) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }
}
