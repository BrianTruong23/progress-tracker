import Foundation

enum EventRecurrence: String, Codable, CaseIterable, Identifiable {
    case none
    case weekly
    case monthly
    case yearly

    var id: Self { self }
    var title: String { rawValue.capitalized }
}

struct CalendarEvent: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var startDate: Date
    var recurrence: EventRecurrence
    var recurrenceWeekdays: [Int]
    var externalEventIdentifier: String?

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        recurrence: EventRecurrence = .none,
        recurrenceWeekdays: [Int] = [],
        externalEventIdentifier: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.recurrence = recurrence
        self.recurrenceWeekdays = recurrenceWeekdays
        self.externalEventIdentifier = externalEventIdentifier
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, startDate, recurrence, recurrenceWeekdays, externalEventIdentifier
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        startDate = try values.decode(Date.self, forKey: .startDate)
        recurrence = try values.decodeIfPresent(EventRecurrence.self, forKey: .recurrence) ?? .none
        recurrenceWeekdays = try values.decodeIfPresent([Int].self, forKey: .recurrenceWeekdays) ?? []
        externalEventIdentifier = try values.decodeIfPresent(String.self, forKey: .externalEventIdentifier)
    }

    func occurs(on date: Date, calendar: Calendar = .current) -> Bool {
        let eventDay = calendar.startOfDay(for: startDate)
        let requestedDay = calendar.startOfDay(for: date)
        guard requestedDay >= eventDay else { return false }

        switch recurrence {
        case .none:
            return calendar.isDate(startDate, inSameDayAs: date)
        case .weekly:
            let weekdays = recurrenceWeekdays.isEmpty
                ? [calendar.component(.weekday, from: startDate)]
                : recurrenceWeekdays
            return weekdays.contains(calendar.component(.weekday, from: date))
        case .monthly:
            return calendar.component(.day, from: startDate) == calendar.component(.day, from: date)
        case .yearly:
            return calendar.component(.month, from: startDate) == calendar.component(.month, from: date)
                && calendar.component(.day, from: startDate) == calendar.component(.day, from: date)
        }
    }
}
