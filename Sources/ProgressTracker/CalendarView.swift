import SwiftUI

struct CalendarView: View {
    @ObservedObject var store: TaskStore
    @StateObject private var googleCalendar = GoogleCalendarSync()
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedDate = Date.now
    @State private var displayedMonth = Calendar.current.dateInterval(of: .month, for: .now)!.start
    @State private var newEventTitle = ""
    @State private var newEventTime = Date.now
    @State private var newEventRecurrence: EventRecurrence = .none
    @State private var recurrenceWeekdays: Set<Int> = []

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            monthCard
                .frame(width: 340)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    dayHeading
                    eventsSection
                    tasksSection
                }
                .padding(.bottom, 10)
            }
        }
        .onAppear {
            if googleCalendar.isConnected { googleCalendar.loadEvents(containing: displayedMonth) }
        }
        .onChange(of: displayedMonth) {
            if googleCalendar.isConnected { googleCalendar.loadEvents(containing: displayedMonth) }
        }
        .onChange(of: googleCalendar.selectedCalendarID) {
            if googleCalendar.isConnected { googleCalendar.loadEvents(containing: displayedMonth) }
        }
        .onChange(of: googleCalendar.accessState) {
            if googleCalendar.isConnected { googleCalendar.loadEvents(containing: displayedMonth) }
        }
        .alert("Calendar Sync Error", isPresented: Binding(
            get: { googleCalendar.errorMessage != nil },
            set: { if !$0 { googleCalendar.errorMessage = nil } }
        )) {
            Button("OK") { googleCalendar.errorMessage = nil }
        } message: {
            Text(googleCalendar.errorMessage ?? "The calendar could not be synchronized.")
        }
    }

    private var monthCard: some View {
        VStack(spacing: 18) {
            HStack {
                Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(CalendarIconButtonStyle())
                Spacer()
                VStack(spacing: 2) {
                    Text(displayedMonth.formatted(.dateTime.month(.wide)))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                    Text(displayedMonth.formatted(.dateTime.year()))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(CalendarIconButtonStyle())
            }

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(calendar.veryShortWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayButton(date)
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }

            Button("Today") {
                selectedDate = .now
                displayedMonth = calendar.dateInterval(of: .month, for: .now)!.start
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.mint)
        }
        .padding(22)
        .background(cardBackground(radius: 24))
    }

    private func dayButton(_ date: Date) -> some View {
        let selected = calendar.isDate(date, inSameDayAs: selectedDate)
        let today = calendar.isDateInToday(date)
        let hasEvents = !store.events(on: date).isEmpty || !googleCalendar.events(on: date).isEmpty
        let hasTasks = !store.tasks(on: date).isEmpty

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 12, weight: selected || today ? .bold : .medium, design: .rounded))
                    .foregroundStyle(selected ? Color.black.opacity(0.8) : today ? Color.mint : Color.primary)
                HStack(spacing: 2) {
                    if hasEvents { Circle().fill(selected ? Color.black.opacity(0.6) : Color.cyan).frame(width: 3, height: 3) }
                    if hasTasks { Circle().fill(selected ? Color.black.opacity(0.6) : Color.yellow).frame(width: 3, height: 3) }
                }
                .frame(height: 3)
            }
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(
                Circle().fill(selected ? Color(red: 0.47, green: 0.95, blue: 0.70) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var dayHeading: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(selectedDate.formatted(.dateTime.month(.wide).day().year()))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if calendar.isDateInToday(selectedDate) {
                Text("TODAY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.mint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.mint.opacity(0.1), in: Capsule())
            }
        }
        .padding(.top, 3)
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("EVENTS", icon: "calendar.badge.clock", count: dayEvents.count + visibleGoogleEvents.count)

            googleCalendarControl

            VStack(spacing: 9) {
                HStack(spacing: 8) {
                    TextField("Add an event…", text: $newEventTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .onSubmit(addEvent)
                    DatePicker("", selection: $newEventTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    Button(action: addEvent) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(CalendarIconButtonStyle())
                    .disabled(newEventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                HStack(spacing: 8) {
                    Label("Repeat", systemImage: "repeat")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Picker("Repeat", selection: $newEventRecurrence) {
                        ForEach(EventRecurrence.allCases) { recurrence in
                            Text(recurrence.title).tag(recurrence)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                    Spacer()
                }

                if newEventRecurrence == .weekly {
                    HStack(spacing: 4) {
                        ForEach(Array(calendar.veryShortWeekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                            let weekday = index + 1
                            Button(symbol.uppercased()) { toggleWeekday(weekday) }
                                .buttonStyle(WeekdayButtonStyle(isSelected: recurrenceWeekdays.contains(weekday)))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))

            if dayEvents.isEmpty && visibleGoogleEvents.isEmpty {
                emptyRow("No events planned", icon: "calendar")
            } else {
                ForEach(dayEvents) { event in
                    HStack(spacing: 11) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.cyan)
                            .frame(width: 4, height: 31)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title).font(.system(size: 13, weight: .semibold))
                            HStack(spacing: 6) {
                                Text(event.startDate.formatted(.dateTime.hour().minute()))
                                if event.recurrence != .none {
                                    Label(recurrenceDescription(for: event), systemImage: "repeat")
                                        .foregroundStyle(Color.cyan)
                                }
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { deleteLocalEvent(event) } label: {
                            Image(systemName: "trash").font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                }

                ForEach(visibleGoogleEvents) { event in
                    HStack(spacing: 11) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(red: 0.26, green: 0.52, blue: 0.96))
                            .frame(width: 4, height: 31)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.system(size: 13, weight: .semibold))
                            HStack(spacing: 6) {
                                Text(event.startDate.formatted(.dateTime.hour().minute()))
                                Label(event.calendarTitle, systemImage: "g.circle.fill")
                                    .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { googleCalendar.deleteEvent(identifier: event.id) } label: {
                            Image(systemName: "trash").font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(16)
        .background(cardBackground(radius: 18))
    }

    @ViewBuilder
    private var googleCalendarControl: some View {
        HStack(spacing: 9) {
            switch googleCalendar.accessState {
            case .connected:
                Image(systemName: "g.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Google Calendar connected")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                    Text("New events sync automatically")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    ForEach(googleCalendar.calendars) { calendar in
                        Button {
                            googleCalendar.selectCalendar(calendar.id)
                        } label: {
                            if calendar.id == googleCalendar.selectedCalendarID {
                                Label("\(calendar.title) — \(calendar.account)", systemImage: "checkmark")
                            } else {
                                Text("\(calendar.title) — \(calendar.account)")
                            }
                        }
                    }
                } label: {
                    Label(googleCalendar.selectedCalendarName, systemImage: "calendar")
                        .font(.system(size: 9, weight: .semibold))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Button {
                    googleCalendar.loadEvents(containing: displayedMonth)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh Google Calendar")

            case .requesting:
                ProgressView().controlSize(.small)
                Text("Connecting to Calendar…")
                    .font(.system(size: 10, weight: .medium))
                Spacer()

            case .notRequested:
                Image(systemName: "g.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                Text("Show and create events in your Google Calendar")
                    .font(.system(size: 10, weight: .medium))
                Spacer()
                Button("Connect Google Calendar") { googleCalendar.connect() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(Color(red: 0.26, green: 0.52, blue: 0.96))

            case .unavailable:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
                Text("Add your Google account in System Settings → Internet Accounts, then reopen the app.")
                    .font(.system(size: 9, weight: .medium))
                Spacer()

            case .denied:
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color.orange)
                Text("Calendar access is off. Enable Progress Tracker in System Settings → Privacy & Security → Calendars.")
                    .font(.system(size: 9, weight: .medium))
                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 11))
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle("TO-DO LIST", icon: "checkmark.circle", count: dayTasks.count)

            if dayTasks.isEmpty {
                emptyRow("No tasks due this day", icon: "checkmark.circle")
            } else {
                ForEach(dayTasks) { task in
                    HStack(spacing: 11) {
                        Button { withAnimation { store.toggle(task) } } label: {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(task.isCompleted ? Color.mint : Color.secondary)
                                .frame(width: 34, height: 34)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .help(task.isCompleted ? "Mark as open" : "Mark as completed")

                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title)
                                .font(.system(size: 13, weight: .semibold))
                                .strikethrough(task.isCompleted)
                                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                            HStack(spacing: 7) {
                                Label(task.project, systemImage: "folder.fill")
                                Text(task.priority.rawValue).foregroundStyle(task.priority.color)
                            }
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.tertiary)

                            if task.link != nil || task.location != nil {
                                HStack(spacing: 8) {
                                    if let link = task.link, let url = URL(string: link) {
                                        Link("Open link", destination: url)
                                    }
                                    if let location = task.location, let url = mapsURL(for: location) {
                                        Link(destination: url) {
                                            Label(location, systemImage: "mappin")
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.cyan)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(16)
        .background(cardBackground(radius: 18))
    }

    private var dayEvents: [CalendarEvent] { store.events(on: selectedDate) }
    private var dayTasks: [TaskItem] { store.tasks(on: selectedDate) }
    private var visibleGoogleEvents: [SyncedCalendarEvent] {
        let linkedIdentifiers = Set(dayEvents.compactMap(\.externalEventIdentifier))
        return googleCalendar.events(on: selectedDate).filter { !linkedIdentifiers.contains($0.id) }
    }

    private var monthDays: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let weekday = calendar.component(.weekday, from: displayedMonth)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + range.compactMap {
            calendar.date(byAdding: .day, value: $0 - 1, to: displayedMonth)
        }.map(Optional.some)
    }

    private func mapsURL(for location: String) -> URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "q", value: location)]
        return components?.url
    }

    private func moveMonth(_ amount: Int) {
        guard let month = calendar.date(byAdding: .month, value: amount, to: displayedMonth) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = month
            selectedDate = month
        }
    }

    private func addEvent() {
        let time = calendar.dateComponents([.hour, .minute], from: newEventTime)
        var day = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        day.hour = time.hour
        day.minute = time.minute
        guard let date = calendar.date(from: day) else { return }
        let selectedWeekday = calendar.component(.weekday, from: selectedDate)
        let weekdays = newEventRecurrence == .weekly
            ? (recurrenceWeekdays.isEmpty ? [selectedWeekday] : Array(recurrenceWeekdays))
            : []
        withAnimation {
            if let localEvent = store.addEvent(newEventTitle, at: date, recurrence: newEventRecurrence, weekdays: weekdays),
               googleCalendar.isConnected,
               let externalIdentifier = googleCalendar.addEvent(
                    title: localEvent.title,
                    startDate: date,
                    recurrence: newEventRecurrence,
                    weekdays: weekdays
               ) {
                store.linkEvent(localEvent.id, toExternalIdentifier: externalIdentifier)
            }
            newEventTitle = ""
        }
    }

    private func deleteLocalEvent(_ event: CalendarEvent) {
        if let identifier = event.externalEventIdentifier {
            googleCalendar.deleteEvent(identifier: identifier)
        }
        withAnimation { store.deleteEvent(event) }
    }

    private func toggleWeekday(_ weekday: Int) {
        if recurrenceWeekdays.contains(weekday) {
            recurrenceWeekdays.remove(weekday)
        } else {
            recurrenceWeekdays.insert(weekday)
        }
    }

    private func recurrenceDescription(for event: CalendarEvent) -> String {
        switch event.recurrence {
        case .none: return ""
        case .weekly:
            let weekdays = event.recurrenceWeekdays.isEmpty
                ? [calendar.component(.weekday, from: event.startDate)]
                : event.recurrenceWeekdays
            let names = weekdays.sorted().map { calendar.shortWeekdaySymbols[$0 - 1] }
            return "Weekly · \(names.joined(separator: ", "))"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }

    private func sectionTitle(_ title: String, icon: String, count: Int) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(count)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private func emptyRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
    }

    private func cardBackground(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Color.appCard(for: colorScheme))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color.primary.opacity(0.075)))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.06), radius: 14, y: 6)
    }
}

private struct WeekdayButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(isSelected ? Color.black.opacity(0.75) : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 25)
            .background(
                isSelected ? Color(red: 0.47, green: 0.94, blue: 0.68) : Color.primary.opacity(0.05),
                in: Capsule()
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct CalendarIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.secondary)
            .frame(width: 28, height: 28)
            .background(Color.primary.opacity(configuration.isPressed ? 0.1 : 0.055), in: Circle())
    }
}
