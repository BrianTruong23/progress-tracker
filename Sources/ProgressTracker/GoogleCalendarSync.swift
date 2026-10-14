import EventKit
import Foundation

struct SyncedCalendar: Identifiable, Equatable {
    let id: String
    let title: String
    let account: String
}

struct SyncedCalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarTitle: String
}

@MainActor
final class GoogleCalendarSync: ObservableObject {
    enum AccessState: Equatable {
        case notRequested
        case requesting
        case connected
        case unavailable
        case denied
    }

    @Published private(set) var accessState: AccessState = .notRequested
    @Published private(set) var calendars: [SyncedCalendar] = []
    @Published private(set) var events: [SyncedCalendarEvent] = []
    @Published private(set) var selectedCalendarID: String?
    @Published var errorMessage: String?

    private let store = EKEventStore()
    private let selectedCalendarKey = "googleCalendarIdentifier"

    init() {
        selectedCalendarID = UserDefaults.standard.string(forKey: selectedCalendarKey)
        refreshAuthorizationState()
    }

    var isConnected: Bool { accessState == .connected && selectedCalendar != nil }

    var selectedCalendarName: String {
        calendars.first(where: { $0.id == selectedCalendarID })?.title ?? "Google Calendar"
    }

    func connect() {
        accessState = .requesting
        Task {
            do {
                let granted = try await store.requestFullAccessToEvents()
                if granted {
                    refreshCalendars()
                } else {
                    accessState = .denied
                }
            } catch {
                errorMessage = error.localizedDescription
                accessState = .denied
            }
        }
    }

    func selectCalendar(_ identifier: String) {
        selectedCalendarID = identifier
        UserDefaults.standard.set(identifier, forKey: selectedCalendarKey)
        events = []
    }

    func loadEvents(containing date: Date) {
        guard let calendar = selectedCalendar else {
            events = []
            return
        }
        let systemCalendar = Calendar.current
        guard let month = systemCalendar.dateInterval(of: .month, for: date),
              let start = systemCalendar.date(byAdding: .day, value: -7, to: month.start),
              let end = systemCalendar.date(byAdding: .day, value: 7, to: month.end) else { return }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: [calendar])
        events = store.events(matching: predicate).map {
            SyncedCalendarEvent(
                id: $0.eventIdentifier ?? UUID().uuidString,
                title: $0.title ?? "Untitled event",
                startDate: $0.startDate,
                endDate: $0.endDate,
                calendarTitle: calendar.title
            )
        }
    }

    func events(on date: Date) -> [SyncedCalendarEvent] {
        events.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
            .sorted { $0.startDate < $1.startDate }
    }

    @discardableResult
    func addEvent(
        title: String,
        startDate: Date,
        recurrence: EventRecurrence,
        weekdays: [Int]
    ) -> String? {
        guard let calendar = selectedCalendar else { return nil }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(60 * 60)
        event.calendar = calendar

        if recurrence != .none {
            let frequency: EKRecurrenceFrequency
            switch recurrence {
            case .none: frequency = .daily
            case .weekly: frequency = .weekly
            case .monthly: frequency = .monthly
            case .yearly: frequency = .yearly
            }
            let recurrenceDays: [EKRecurrenceDayOfWeek]? = recurrence == .weekly
                ? (weekdays.isEmpty ? nil : weekdays.compactMap { day in
                    guard let weekday = EKWeekday(rawValue: day) else { return nil }
                    return EKRecurrenceDayOfWeek(weekday)
                })
                : nil
            event.recurrenceRules = [EKRecurrenceRule(
                recurrenceWith: frequency,
                interval: 1,
                daysOfTheWeek: recurrenceDays,
                daysOfTheMonth: nil,
                monthsOfTheYear: nil,
                weeksOfTheYear: nil,
                daysOfTheYear: nil,
                setPositions: nil,
                end: nil
            )]
        }

        do {
            try store.save(event, span: .futureEvents, commit: true)
            loadEvents(containing: startDate)
            return event.eventIdentifier
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func deleteEvent(identifier: String) {
        guard let event = store.event(withIdentifier: identifier) else { return }
        let date = event.startDate ?? .now
        do {
            try store.remove(event, span: .futureEvents, commit: true)
            loadEvents(containing: date)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var selectedCalendar: EKCalendar? {
        guard let selectedCalendarID else { return nil }
        return store.calendar(withIdentifier: selectedCalendarID)
    }

    private func refreshAuthorizationState() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .authorized:
            refreshCalendars()
        case .denied, .restricted, .writeOnly:
            accessState = .denied
        case .notDetermined:
            accessState = .notRequested
        @unknown default:
            accessState = .unavailable
        }
    }

    private func refreshCalendars() {
        let available = store.calendars(for: .event)
            .filter { $0.source.sourceType == .calDAV && $0.allowsContentModifications }
            .map { SyncedCalendar(id: $0.calendarIdentifier, title: $0.title, account: $0.source.title) }
            .sorted {
                if $0.account != $1.account { return $0.account < $1.account }
                return $0.title < $1.title
            }
        calendars = available

        if available.isEmpty {
            accessState = .unavailable
            return
        }
        if selectedCalendarID == nil || !available.contains(where: { $0.id == selectedCalendarID }) {
            selectedCalendarID = available.first?.id
            UserDefaults.standard.set(selectedCalendarID, forKey: selectedCalendarKey)
        }
        accessState = .connected
    }
}
