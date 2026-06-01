// AustralianPublicHolidays.swift
// CanIPark

import Foundation

// MARK: - Australian State

enum AustralianState: String, Codable, CaseIterable, Identifiable {
    case nsw, vic, qld, sa, wa, tas, act, nt

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nsw: return "New South Wales"
        case .vic: return "Victoria"
        case .qld: return "Queensland"
        case .sa:  return "South Australia"
        case .wa:  return "Western Australia"
        case .tas: return "Tasmania"
        case .act: return "Australian Capital Territory"
        case .nt:  return "Northern Territory"
        }
    }

    var abbreviation: String {
        rawValue.uppercased()
    }

    /// Whether this state observes daylight saving time.
    var observesDST: Bool {
        switch self {
        case .nsw, .vic, .tas, .act, .sa:
            return true
        case .qld, .wa, .nt:
            return false
        }
    }

    /// The IANA time zone identifier for this state.
    var timeZoneIdentifier: String {
        switch self {
        case .nsw: return "Australia/Sydney"
        case .vic: return "Australia/Melbourne"
        case .qld: return "Australia/Brisbane"
        case .sa:  return "Australia/Adelaide"
        case .wa:  return "Australia/Perth"
        case .tas: return "Australia/Hobart"
        case .act: return "Australia/Sydney"
        case .nt:  return "Australia/Darwin"
        }
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier)!
    }
}

// MARK: - Easter Calculation (Anonymous Gregorian Algorithm)

/// Computes Easter Sunday for a given Gregorian year using the Anonymous Gregorian algorithm.
func easterSunday(year: Int) -> DateComponents {
    let a = year % 19
    let b = year / 100
    let c = year % 100
    let d = b / 4
    let e = b % 4
    let f = (b + 8) / 25
    let g = (b - f + 1) / 3
    let h = (19 * a + b - d - g + 15) % 30
    let i = c / 4
    let k = c % 4
    let l = (32 + 2 * e + 2 * i - h - k) % 7
    let m = (a + 11 * h + 22 * l) / 451
    let month = (h + l - 7 * m + 114) / 31
    let day = ((h + l - 7 * m + 114) % 31) + 1
    return DateComponents(year: year, month: month, day: day)
}

// MARK: - Australian Public Holidays

struct AustralianPublicHolidays {

    private static var gregorianCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return cal
    }

    // MARK: Public API

    /// Returns `true` if the given date is a public holiday in the specified state.
    /// An optional council name can be provided for council-specific holidays (e.g., Recreation Day in TAS).
    static func isPublicHoliday(date: Date, state: AustralianState, council: String? = nil) -> Bool {
        let cal = calendarForState(state)
        let year = cal.component(.year, from: date)
        let holidays = allHolidays(year: year, state: state, council: council, calendar: cal)
        let dateDay = cal.startOfDay(for: date)
        return holidays.contains { cal.isDate($0, inSameDayAs: dateDay) }
    }

    /// Returns all public holiday dates for a given year, state, and optional council.
    static func allHolidays(year: Int, state: AustralianState, council: String? = nil,
                            calendar: Calendar? = nil) -> [Date] {
        let cal = calendar ?? calendarForState(state)
        var holidays = nationalHolidays(year: year, calendar: cal)
        holidays.append(contentsOf: stateHolidays(year: year, state: state, council: council, calendar: cal))
        return holidays
    }

    // MARK: Calendar Helper

    private static func calendarForState(_ state: AustralianState) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = state.timeZone
        return cal
    }

    // MARK: National Holidays

    private static func nationalHolidays(year: Int, calendar cal: Calendar) -> [Date] {
        var dates: [Date] = []

        // New Year's Day - January 1 (substitute if on weekend)
        dates.append(contentsOf: substituteWeekend(year: year, month: 1, day: 1, calendar: cal))

        // Australia Day - January 26 (substitute if on weekend)
        dates.append(contentsOf: substituteWeekend(year: year, month: 1, day: 26, calendar: cal))

        // Easter
        let easter = easterSunday(year: year)
        if let easterDate = cal.date(from: easter) {
            // Good Friday (Easter Sunday - 2)
            if let goodFriday = cal.date(byAdding: .day, value: -2, to: easterDate) {
                dates.append(goodFriday)
            }
            // Easter Saturday (Easter Sunday - 1)
            if let easterSat = cal.date(byAdding: .day, value: -1, to: easterDate) {
                dates.append(easterSat)
            }
            // Easter Monday (Easter Sunday + 1)
            if let easterMon = cal.date(byAdding: .day, value: 1, to: easterDate) {
                dates.append(easterMon)
            }
        }

        // Anzac Day - April 25 (no substitute for weekends nationally, but some states do)
        if let anzac = cal.date(from: DateComponents(year: year, month: 4, day: 25)) {
            dates.append(anzac)
        }

        // Queen's/King's Birthday is state-specific, added in stateHolidays

        // Christmas Day - December 25 (substitute if on weekend)
        dates.append(contentsOf: substituteChristmasBoxingDay(year: year, calendar: cal))

        return dates
    }

    // MARK: State-Specific Holidays

    private static func stateHolidays(year: Int, state: AustralianState, council: String?,
                                      calendar cal: Calendar) -> [Date] {
        var dates: [Date] = []

        switch state {
        case .nsw:
            // Bank Holiday: first Monday in August
            dates.append(contentsOf: nthWeekday(nth: 1, weekday: 2, month: 8, year: year, calendar: cal))
            // King's Birthday: second Monday in June
            dates.append(contentsOf: nthWeekday(nth: 2, weekday: 2, month: 6, year: year, calendar: cal))
            // Easter Sunday
            if let easterDate = cal.date(from: easterSunday(year: year)) {
                dates.append(easterDate)
            }

        case .vic:
            // Melbourne Cup Day: first Tuesday in November
            dates.append(contentsOf: nthWeekday(nth: 1, weekday: 3, month: 11, year: year, calendar: cal))
            // King's Birthday: second Monday in June
            dates.append(contentsOf: nthWeekday(nth: 2, weekday: 2, month: 6, year: year, calendar: cal))
            // Easter Sunday
            if let easterDate = cal.date(from: easterSunday(year: year)) {
                dates.append(easterDate)
            }
            // AFL Grand Final Friday (approximate: last Friday in September)
            dates.append(contentsOf: lastWeekday(weekday: 6, month: 9, year: year, calendar: cal))

        case .qld:
            // King's Birthday: last Monday in October
            dates.append(contentsOf: lastWeekday(weekday: 2, month: 10, year: year, calendar: cal))
            // Royal Queensland Show (Ekka): second or third Wednesday in August (Brisbane only)
            if let councilName = council?.lowercased(), councilName.contains("brisbane") {
                dates.append(contentsOf: nthWeekday(nth: 2, weekday: 4, month: 8, year: year, calendar: cal))
            }

        case .sa:
            // Adelaide Cup: second Monday in March
            dates.append(contentsOf: nthWeekday(nth: 2, weekday: 2, month: 3, year: year, calendar: cal))
            // King's Birthday: second Monday in June
            dates.append(contentsOf: nthWeekday(nth: 2, weekday: 2, month: 6, year: year, calendar: cal))
            // Proclamation Day: December 24 (substitute if on weekend)
            dates.append(contentsOf: substituteWeekend(year: year, month: 12, day: 24, calendar: cal))
            // Easter Saturday
            if let easterDate = cal.date(from: easterSunday(year: year)) {
                if let easterSat = cal.date(byAdding: .day, value: -1, to: easterDate) {
                    dates.append(easterSat)
                }
            }

        case .wa:
            // Western Australia Day: June 1
            dates.append(contentsOf: substituteWeekend(year: year, month: 6, day: 1, calendar: cal))
            // King's Birthday: fourth Monday in September
            dates.append(contentsOf: nthWeekday(nth: 4, weekday: 2, month: 9, year: year, calendar: cal))

        case .tas:
            // Royal Hobart Regatta: second Monday in February (southern Tasmania only)
            if let councilName = council?.lowercased(),
               councilName.contains("hobart") || councilName.contains("kingborough")
                || councilName.contains("huon") || councilName.contains("channel") {
                dates.append(contentsOf: nthWeekday(nth: 2, weekday: 2, month: 2, year: year, calendar: cal))
            }
            // King's Birthday: second Monday in June
            dates.append(contentsOf: nthWeekday(nth: 2, weekday: 2, month: 6, year: year, calendar: cal))
            // Recreation Day: first Monday in November (northern Tasmania, where Royal Hobart Regatta is not observed)
            let isSouthernCouncil: Bool = {
                guard let name = council?.lowercased() else { return false }
                return name.contains("hobart") || name.contains("kingborough")
                    || name.contains("huon") || name.contains("channel")
            }()
            if !isSouthernCouncil {
                dates.append(contentsOf: nthWeekday(nth: 1, weekday: 2, month: 11, year: year, calendar: cal))
            }

        case .act:
            // Canberra Day: second Monday in March
            dates.append(contentsOf: nthWeekday(nth: 2, weekday: 2, month: 3, year: year, calendar: cal))
            // Reconciliation Day: May 27 (substitute if on weekend)
            dates.append(contentsOf: substituteWeekend(year: year, month: 5, day: 27, calendar: cal))
            // King's Birthday: second Monday in June
            dates.append(contentsOf: nthWeekday(nth: 2, weekday: 2, month: 6, year: year, calendar: cal))
            // Family & Community Day: last Monday before or on September 30
            // (Changed to be the Monday before or on Sep 30 — effectively last Mon in Sept)
            dates.append(contentsOf: lastWeekday(weekday: 2, month: 9, year: year, calendar: cal))
            // Easter Sunday
            if let easterDate = cal.date(from: easterSunday(year: year)) {
                dates.append(easterDate)
            }

        case .nt:
            // May Day: first Monday in May
            dates.append(contentsOf: nthWeekday(nth: 1, weekday: 2, month: 5, year: year, calendar: cal))
            // King's Birthday: second Monday in June
            dates.append(contentsOf: nthWeekday(nth: 2, weekday: 2, month: 6, year: year, calendar: cal))
            // Picnic Day: first Monday in August
            dates.append(contentsOf: nthWeekday(nth: 1, weekday: 2, month: 8, year: year, calendar: cal))
            // Easter Saturday
            if let easterDate = cal.date(from: easterSunday(year: year)) {
                if let easterSat = cal.date(byAdding: .day, value: -1, to: easterDate) {
                    dates.append(easterSat)
                }
            }
        }

        return dates
    }

    // MARK: - Date Helpers

    /// Returns the date for the nth occurrence of a weekday in a given month/year.
    /// `weekday` uses Calendar convention: 1 = Sunday, 2 = Monday, ..., 7 = Saturday.
    private static func nthWeekday(nth: Int, weekday: Int, month: Int, year: Int,
                                   calendar cal: Calendar) -> [Date] {
        var components = DateComponents(year: year, month: month)
        components.weekday = weekday
        components.weekdayOrdinal = nth
        if let date = cal.date(from: components) {
            return [date]
        }
        return []
    }

    /// Returns the date for the last occurrence of a weekday in a given month/year.
    private static func lastWeekday(weekday: Int, month: Int, year: Int,
                                    calendar cal: Calendar) -> [Date] {
        // Find the last day of the month, then walk backward
        var components = DateComponents(year: year, month: month)
        guard let range = cal.range(of: .day, in: .month, for: cal.date(from: components)!) else { return [] }
        let lastDay = range.upperBound - 1
        components.day = lastDay
        guard let endOfMonth = cal.date(from: components) else { return [] }

        let endWeekday = cal.component(.weekday, from: endOfMonth)
        var diff = endWeekday - weekday
        if diff < 0 { diff += 7 }

        if let result = cal.date(byAdding: .day, value: -diff, to: endOfMonth) {
            return [result]
        }
        return []
    }

    /// If the holiday falls on Saturday, the following Monday is the substitute.
    /// If it falls on Sunday, the following Monday is the substitute.
    /// Returns both the actual date and substitute if applicable.
    private static func substituteWeekend(year: Int, month: Int, day: Int,
                                          calendar cal: Calendar) -> [Date] {
        guard let date = cal.date(from: DateComponents(year: year, month: month, day: day)) else {
            return []
        }
        let weekday = cal.component(.weekday, from: date)
        switch weekday {
        case 7: // Saturday -> Monday substitute
            if let sub = cal.date(byAdding: .day, value: 2, to: date) {
                return [date, sub]
            }
        case 1: // Sunday -> Monday substitute
            if let sub = cal.date(byAdding: .day, value: 1, to: date) {
                return [date, sub]
            }
        default:
            break
        }
        return [date]
    }

    /// Handle Christmas/Boxing Day substitution together to avoid double-Monday conflicts.
    private static func substituteChristmasBoxingDay(year: Int, calendar cal: Calendar) -> [Date] {
        guard let christmas = cal.date(from: DateComponents(year: year, month: 12, day: 25)),
              let boxingDay = cal.date(from: DateComponents(year: year, month: 12, day: 26)) else {
            return []
        }

        var dates: [Date] = [christmas, boxingDay]
        let christmasWeekday = cal.component(.weekday, from: christmas)

        switch christmasWeekday {
        case 6: // Christmas=Friday, Boxing Day=Saturday -> Boxing Day sub on Monday 28th
            if let sub = cal.date(byAdding: .day, value: 2, to: boxingDay) {
                dates.append(sub)
            }
        case 7: // Christmas=Saturday, Boxing Day=Sunday -> Christmas sub Mon 27, Boxing sub Tue 28
            if let christmasSub = cal.date(byAdding: .day, value: 2, to: christmas),
               let boxingSub = cal.date(byAdding: .day, value: 2, to: boxingDay) {
                dates.append(christmasSub)
                dates.append(boxingSub)
            }
        case 1: // Christmas=Sunday, Boxing Day=Monday -> Christmas sub on Tuesday 27
            if let sub = cal.date(byAdding: .day, value: 1, to: boxingDay) {
                dates.append(sub)
            }
        default:
            break
        }

        return dates
    }
}
