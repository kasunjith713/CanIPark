// DateTimeEvaluator.swift
// CanIPark

import Foundation

// MARK: - Date Time Evaluator

/// Evaluates parking time windows against the current date/time, incorporating
/// Australian public holidays, school term dates, and state-specific time zones.
struct DateTimeEvaluator {

    // MARK: - Configuration

    struct Configuration {
        let state: AustralianState
        let council: String?
        let date: Date
        let calendar: Calendar

        init(state: AustralianState, council: String? = nil, date: Date = Date()) {
            self.state = state
            self.council = council
            self.date = date
            self.calendar = AustralianTimeZones.calendar(for: state)
        }
    }

    // MARK: - Evaluation Result

    struct EvaluationResult {
        /// Whether the restriction is currently active.
        let isActive: Bool

        /// Whether right now is a public holiday.
        let isPublicHoliday: Bool

        /// Whether right now is a school day.
        let isSchoolDay: Bool

        /// The time remaining until the restriction status changes, or `nil` if unknown.
        let timeUntilChange: TimeInterval?

        /// A human-readable description of when the restriction next changes.
        let nextChangeDescription: String?

        /// The specific time window that is currently active, or `nil` if none.
        let activeTimeWindow: TimeWindow?
    }

    // MARK: - Single Time Window Evaluation

    /// Evaluates whether a single `TimeWindow` is active at the configured date/time.
    static func evaluate(timeWindow: TimeWindow, configuration: Configuration) -> EvaluationResult {
        let cal = configuration.calendar
        let date = configuration.date
        let state = configuration.state

        let isPublicHoliday = AustralianPublicHolidays.isPublicHoliday(
            date: date, state: state, council: configuration.council
        )
        let isSchoolDay = SchoolTermDates.isSchoolDay(date: date, state: state)

        let isActive = timeWindow.contains(
            date: date, calendar: cal, isSchoolDay: isSchoolDay, isPublicHoliday: isPublicHoliday
        )

        let nextChange = computeNextChange(
            timeWindow: timeWindow, date: date, calendar: cal,
            isSchoolDay: isSchoolDay, isPublicHoliday: isPublicHoliday, state: state
        )

        return EvaluationResult(
            isActive: isActive,
            isPublicHoliday: isPublicHoliday,
            isSchoolDay: isSchoolDay,
            timeUntilChange: nextChange.interval,
            nextChangeDescription: nextChange.description,
            activeTimeWindow: isActive ? timeWindow : nil
        )
    }

    // MARK: - Multiple Time Windows Evaluation

    /// Evaluates an array of time windows and returns the result for the first active one,
    /// or a result indicating no windows are active.
    static func evaluate(timeWindows: [TimeWindow], configuration: Configuration) -> EvaluationResult {
        let cal = configuration.calendar
        let date = configuration.date
        let state = configuration.state

        let isPublicHoliday = AustralianPublicHolidays.isPublicHoliday(
            date: date, state: state, council: configuration.council
        )
        let isSchoolDay = SchoolTermDates.isSchoolDay(date: date, state: state)

        // Find the first active time window
        for window in timeWindows {
            let active = window.contains(
                date: date, calendar: cal, isSchoolDay: isSchoolDay, isPublicHoliday: isPublicHoliday
            )
            if active {
                let nextChange = computeNextChange(
                    timeWindow: window, date: date, calendar: cal,
                    isSchoolDay: isSchoolDay, isPublicHoliday: isPublicHoliday, state: state
                )
                return EvaluationResult(
                    isActive: true,
                    isPublicHoliday: isPublicHoliday,
                    isSchoolDay: isSchoolDay,
                    timeUntilChange: nextChange.interval,
                    nextChangeDescription: nextChange.description,
                    activeTimeWindow: window
                )
            }
        }

        // No active window — find when the next one activates
        let nextActivation = computeNextActivation(
            timeWindows: timeWindows, date: date, calendar: cal, state: state,
            council: configuration.council
        )

        return EvaluationResult(
            isActive: false,
            isPublicHoliday: isPublicHoliday,
            isSchoolDay: isSchoolDay,
            timeUntilChange: nextActivation.interval,
            nextChangeDescription: nextActivation.description,
            activeTimeWindow: nil
        )
    }

    // MARK: - Restriction Evaluation

    /// Evaluates a full `ParkingRestriction` at the configured date/time.
    static func evaluate(restriction: ParkingRestriction, configuration: Configuration) -> EvaluationResult {
        if restriction.timeWindows.isEmpty {
            // Always-active restrictions
            let isPublicHoliday = AustralianPublicHolidays.isPublicHoliday(
                date: configuration.date, state: configuration.state, council: configuration.council
            )
            let isSchoolDay = SchoolTermDates.isSchoolDay(date: configuration.date, state: configuration.state)

            return EvaluationResult(
                isActive: true,
                isPublicHoliday: isPublicHoliday,
                isSchoolDay: isSchoolDay,
                timeUntilChange: nil,
                nextChangeDescription: "This restriction is always active.",
                activeTimeWindow: nil
            )
        }

        return evaluate(timeWindows: restriction.timeWindows, configuration: configuration)
    }

    // MARK: - Convenience Methods

    /// Quick check: is the restriction currently active?
    static func isActive(restriction: ParkingRestriction, state: AustralianState,
                         council: String? = nil, at date: Date = Date()) -> Bool {
        let config = Configuration(state: state, council: council, date: date)
        return evaluate(restriction: restriction, configuration: config).isActive
    }

    /// Quick check: is the time window currently active?
    static func isActive(timeWindow: TimeWindow, state: AustralianState,
                         council: String? = nil, at date: Date = Date()) -> Bool {
        let config = Configuration(state: state, council: council, date: date)
        return evaluate(timeWindow: timeWindow, configuration: config).isActive
    }

    /// Returns context information for the ParkingDecisionEngine.
    static func contextForEngine(state: AustralianState, council: String? = nil,
                                 at date: Date = Date()) -> (isSchoolDay: Bool, isPublicHoliday: Bool) {
        let isPublicHoliday = AustralianPublicHolidays.isPublicHoliday(
            date: date, state: state, council: council
        )
        let isSchoolDay = SchoolTermDates.isSchoolDay(date: date, state: state)
        return (isSchoolDay: isSchoolDay, isPublicHoliday: isPublicHoliday)
    }

    // MARK: - Next Change Computation

    private struct NextChange {
        let interval: TimeInterval?
        let description: String?
    }

    /// Computes when the current time window will end (if active) by looking at its end time today.
    private static func computeNextChange(timeWindow: TimeWindow, date: Date, calendar cal: Calendar,
                                          isSchoolDay: Bool, isPublicHoliday: Bool,
                                          state: AustralianState) -> NextChange {
        // If the window is all day and every day, it never changes
        if timeWindow.isAllDay && timeWindow.isEveryDay
            && !timeWindow.schoolDaysOnly
            && timeWindow.publicHolidayBehavior == .unspecified {
            return NextChange(interval: nil, description: "This restriction is always active.")
        }

        // Calculate end of current window today
        let endTimeToday = cal.date(
            bySettingHour: timeWindow.endTime.hour,
            minute: timeWindow.endTime.minute,
            second: 59,
            of: date
        )

        if let endDate = endTimeToday, endDate > date {
            let interval = endDate.timeIntervalSince(date)
            let description = formatTimeInterval(interval)
            return NextChange(interval: interval, description: "Ends in \(description)")
        }

        // Current window ends today — find next occurrence
        return NextChange(interval: nil, description: "Ends today at \(timeWindow.endTime.formatted)")
    }

    /// Scans the next 7 days to find when any of the time windows will next activate.
    private static func computeNextActivation(timeWindows: [TimeWindow], date: Date,
                                              calendar cal: Calendar, state: AustralianState,
                                              council: String?) -> NextChange {
        // Check every 30-minute slot over the next 7 days
        let maxLookahead = 7 * 24 * 2 // 7 days in 30-minute increments
        var checkDate = date

        for _ in 0..<maxLookahead {
            guard let next = cal.date(byAdding: .minute, value: 30, to: checkDate) else { break }
            checkDate = next

            let isHoliday = AustralianPublicHolidays.isPublicHoliday(
                date: checkDate, state: state, council: council
            )
            let isSchool = SchoolTermDates.isSchoolDay(date: checkDate, state: state)

            for window in timeWindows {
                if window.contains(date: checkDate, calendar: cal,
                                   isSchoolDay: isSchool, isPublicHoliday: isHoliday) {
                    let interval = checkDate.timeIntervalSince(date)
                    let dayName = dayDescription(date: checkDate, relativeTo: date, calendar: cal)
                    let description = "Starts \(dayName) at \(window.startTime.formatted)"
                    return NextChange(interval: interval, description: description)
                }
            }
        }

        return NextChange(interval: nil, description: nil)
    }

    // MARK: - Formatting Helpers

    private static func formatTimeInterval(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else if minutes == 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s") \(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }

    private static func dayDescription(date: Date, relativeTo reference: Date, calendar cal: Calendar) -> String {
        if cal.isDateInToday(date) {
            return "today"
        } else if cal.isDateInTomorrow(date) {
            return "tomorrow"
        } else {
            let weekday = cal.component(.weekday, from: date)
            if let day = DayOfWeek.fromCalendarWeekday(weekday) {
                return "on \(day.fullName)"
            }
            return "soon"
        }
    }
}
