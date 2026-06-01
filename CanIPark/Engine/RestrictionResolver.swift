// RestrictionResolver.swift
// CanIPark

import Foundation

struct RestrictionResolver {

    struct ResolutionResult {
        let activeRestriction: ParkingRestriction?
        let activeTimeWindow: TimeWindow?
        let confidence: Double
        let allActiveRestrictions: [ParkingRestriction]
        let isUnrestricted: Bool

        static let unrestricted = ResolutionResult(
            activeRestriction: nil, activeTimeWindow: nil,
            confidence: 0.85, allActiveRestrictions: [], isUnrestricted: true
        )
    }

    struct Context {
        let dateTime: Date
        let calendar: Calendar
        let isSchoolDay: Bool
        let isPublicHoliday: Bool

        init(dateTime: Date, calendar: Calendar = .current, isSchoolDay: Bool = false, isPublicHoliday: Bool = false) {
            self.dateTime = dateTime
            self.calendar = calendar
            self.isSchoolDay = isSchoolDay
            self.isPublicHoliday = isPublicHoliday
        }
    }

    static func resolve(restrictions: [ParkingRestriction], context: Context) -> ResolutionResult {
        guard !restrictions.isEmpty else { return .unrestricted }

        var activeRestrictions: [ParkingRestriction] = []
        for restriction in restrictions {
            if restriction.isActive(at: context.dateTime, calendar: context.calendar,
                                     isSchoolDay: context.isSchoolDay, isPublicHoliday: context.isPublicHoliday) {
                activeRestrictions.append(restriction)
            }
        }

        if activeRestrictions.isEmpty {
            return ResolutionResult(
                activeRestriction: nil, activeTimeWindow: nil,
                confidence: computeUnrestrictedConfidence(restrictions: restrictions),
                allActiveRestrictions: [], isUnrestricted: true
            )
        }

        activeRestrictions.sort { $0.category.precedence < $1.category.precedence }
        let winner = activeRestrictions[0]
        let activeWindow = findActiveTimeWindow(for: winner, context: context)
        let confidence = computeResolutionConfidence(winner: winner, allActive: activeRestrictions, context: context)

        return ResolutionResult(
            activeRestriction: winner, activeTimeWindow: activeWindow,
            confidence: confidence, allActiveRestrictions: activeRestrictions, isUnrestricted: false
        )
    }

    static func nextChangeTime(for restrictions: [ParkingRestriction], context: Context) -> Date? {
        let calendar = context.calendar
        let now = context.dateTime
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentTime = TimeOfDay(hour: currentHour, minute: currentMinute)

        var earliestChange: Date?

        for restriction in restrictions {
            for window in restriction.timeWindows {
                let weekday = calendar.component(.weekday, from: now)
                guard let day = DayOfWeek.fromCalendarWeekday(weekday) else { continue }

                if window.daysOfWeek.contains(day) {
                    if currentTime >= window.startTime && currentTime <= window.endTime {
                        if let change = dateFromTimeOfDay(window.endTime, relativeTo: now, calendar: calendar) {
                            if earliestChange == nil || change < earliestChange! { earliestChange = change }
                        }
                    } else if currentTime < window.startTime {
                        if let change = dateFromTimeOfDay(window.startTime, relativeTo: now, calendar: calendar) {
                            if earliestChange == nil || change < earliestChange! { earliestChange = change }
                        }
                    }
                }

                if currentTime > window.endTime || !window.daysOfWeek.contains(day) {
                    if let nextDate = nextOccurrenceOfWindow(window, after: now, calendar: calendar) {
                        if earliestChange == nil || nextDate < earliestChange! { earliestChange = nextDate }
                    }
                }
            }
        }

        return earliestChange
    }

    private static func findActiveTimeWindow(for restriction: ParkingRestriction, context: Context) -> TimeWindow? {
        restriction.timeWindows.first { $0.contains(date: context.dateTime, calendar: context.calendar,
                                                      isSchoolDay: context.isSchoolDay, isPublicHoliday: context.isPublicHoliday) }
    }

    private static func computeUnrestrictedConfidence(restrictions: [ParkingRestriction]) -> Double {
        if restrictions.isEmpty { return 0.5 }
        return restrictions.allSatisfy({ !$0.timeWindows.isEmpty }) ? 0.85 : 0.65
    }

    private static func computeResolutionConfidence(winner: ParkingRestriction, allActive: [ParkingRestriction], context: Context) -> Double {
        var confidence = winner.confidence
        if allActive.count > 1 && Set(allActive.map { $0.category }).count > 1 { confidence *= 0.90 }

        let hour = context.calendar.component(.hour, from: context.dateTime)
        let minute = context.calendar.component(.minute, from: context.dateTime)
        let currentTime = TimeOfDay(hour: hour, minute: minute)

        if let window = findActiveTimeWindow(for: winner, context: context) {
            let minutesToEnd = window.endTime.totalMinutes - currentTime.totalMinutes
            if minutesToEnd <= 5 && minutesToEnd >= 0 { confidence *= 0.85 }
        }

        return min(1.0, max(0.0, confidence))
    }

    private static func dateFromTimeOfDay(_ time: TimeOfDay, relativeTo reference: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: reference)
        components.hour = time.hour
        components.minute = time.minute
        components.second = 0
        return calendar.date(from: components)
    }

    private static func nextOccurrenceOfWindow(_ window: TimeWindow, after date: Date, calendar: Calendar) -> Date? {
        for dayOffset in 1...7 {
            guard let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: date) else { continue }
            let weekday = calendar.component(.weekday, from: futureDate)
            guard let day = DayOfWeek.fromCalendarWeekday(weekday) else { continue }
            if window.daysOfWeek.contains(day) {
                return dateFromTimeOfDay(window.startTime, relativeTo: futureDate, calendar: calendar)
            }
        }
        return nil
    }
}
