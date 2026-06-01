// SchoolTermDates.swift
// CanIPark

import Foundation

// MARK: - School Term Dates

/// Provides approximate school term dates for Australian states from 2024 to 2030.
/// Used to determine whether parking restrictions marked "school days only" are active.
struct SchoolTermDates {

    /// A school term defined by inclusive start and end dates.
    struct Term {
        let start: DateComponents
        let end: DateComponents

        func contains(date: Date, calendar: Calendar) -> Bool {
            guard let startDate = calendar.date(from: start),
                  let endDate = calendar.date(from: end) else { return false }
            let dayStart = calendar.startOfDay(for: startDate)
            let dayEnd = calendar.startOfDay(for: endDate)
            let dayCheck = calendar.startOfDay(for: date)
            return dayCheck >= dayStart && dayCheck <= dayEnd
        }
    }

    /// A full year of four school terms.
    struct SchoolYear {
        let year: Int
        let terms: [Term]

        func isInTerm(date: Date, calendar: Calendar) -> Bool {
            return terms.contains { $0.contains(date: date, calendar: calendar) }
        }
    }

    // MARK: - Public API

    /// Returns `true` if the given date is a school day in the specified state.
    /// A school day is a weekday that falls within a school term and is not a public holiday.
    static func isSchoolDay(date: Date, state: AustralianState) -> Bool {
        let cal = AustralianTimeZones.calendar(for: state)
        let weekday = cal.component(.weekday, from: date)

        // Must be a weekday (Monday=2 through Friday=6 in Calendar)
        guard weekday >= 2 && weekday <= 6 else { return false }

        // Must not be a public holiday
        if AustralianPublicHolidays.isPublicHoliday(date: date, state: state) {
            return false
        }

        // Must be within a school term
        return isInTerm(date: date, state: state, calendar: cal)
    }

    /// Returns `true` if the given date falls within a school term for the state.
    static func isInTerm(date: Date, state: AustralianState, calendar: Calendar? = nil) -> Bool {
        let cal = calendar ?? AustralianTimeZones.calendar(for: state)
        let year = cal.component(.year, from: date)

        guard let schoolYear = termDates(for: year, state: state) else {
            // If we don't have data for this year, use a conservative estimate
            return estimateIsInTerm(date: date, calendar: cal)
        }

        return schoolYear.isInTerm(date: date, calendar: cal)
    }

    // MARK: - Term Date Lookup

    /// Returns the school terms for a given year and state.
    /// Returns `nil` if the year is outside the supported range.
    static func termDates(for year: Int, state: AustralianState) -> SchoolYear? {
        guard year >= 2024 && year <= 2030 else { return nil }

        // Most states follow very similar schedules. We provide approximate dates.
        // These are based on published gazetted dates and may shift slightly year to year.
        switch state {
        case .nsw:
            return nswTerms(year: year)
        case .vic:
            return vicTerms(year: year)
        case .qld:
            return qldTerms(year: year)
        case .sa:
            return saTerms(year: year)
        case .wa:
            return waTerms(year: year)
        case .tas:
            return tasTerms(year: year)
        case .act:
            return actTerms(year: year)
        case .nt:
            return ntTerms(year: year)
        }
    }

    // MARK: - Fallback Estimate

    /// Estimates whether a date is in term using typical Australian school calendar patterns.
    private static func estimateIsInTerm(date: Date, calendar cal: Calendar) -> Bool {
        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)

        // Typical Australian school holidays:
        // Late Dec - late Jan (summer)
        // ~2 weeks in Apr (autumn)
        // ~2 weeks in Jul (winter)
        // ~2 weeks in Sep/Oct (spring)
        switch month {
        case 1:
            return day >= 28 // Term 1 typically starts late January
        case 2, 3:
            return true
        case 4:
            return day <= 5 || day >= 22 // Autumn break mid-April
        case 5, 6:
            return true
        case 7:
            return day >= 15 // Winter break first 2 weeks of July
        case 8, 9:
            return true
        case 10:
            return day >= 8 // Spring break late Sep to early Oct
        case 11:
            return true
        case 12:
            return day <= 18 // Summer break starts mid-December
        default:
            return false
        }
    }

    // MARK: - State Term Dates

    // Approximate term dates for each state. These are based on published schedules and
    // may differ slightly from actual gazetted dates. The important thing for parking
    // enforcement is to be roughly correct — exact precision is less critical than
    // capturing the general school period.

    private static func nswTerms(year: Int) -> SchoolYear {
        switch year {
        case 2024:
            return SchoolYear(year: 2024, terms: [
                Term(start: dc(2024, 1, 29), end: dc(2024, 4, 12)),
                Term(start: dc(2024, 4, 29), end: dc(2024, 7, 5)),
                Term(start: dc(2024, 7, 22), end: dc(2024, 9, 27)),
                Term(start: dc(2024, 10, 14), end: dc(2024, 12, 18)),
            ])
        case 2025:
            return SchoolYear(year: 2025, terms: [
                Term(start: dc(2025, 1, 28), end: dc(2025, 4, 11)),
                Term(start: dc(2025, 4, 28), end: dc(2025, 7, 4)),
                Term(start: dc(2025, 7, 21), end: dc(2025, 9, 26)),
                Term(start: dc(2025, 10, 13), end: dc(2025, 12, 17)),
            ])
        case 2026:
            return SchoolYear(year: 2026, terms: [
                Term(start: dc(2026, 1, 27), end: dc(2026, 4, 2)),
                Term(start: dc(2026, 4, 20), end: dc(2026, 7, 3)),
                Term(start: dc(2026, 7, 20), end: dc(2026, 9, 25)),
                Term(start: dc(2026, 10, 12), end: dc(2026, 12, 16)),
            ])
        case 2027:
            return SchoolYear(year: 2027, terms: [
                Term(start: dc(2027, 1, 27), end: dc(2027, 4, 1)),
                Term(start: dc(2027, 4, 19), end: dc(2027, 7, 2)),
                Term(start: dc(2027, 7, 19), end: dc(2027, 9, 24)),
                Term(start: dc(2027, 10, 11), end: dc(2027, 12, 16)),
            ])
        case 2028:
            return SchoolYear(year: 2028, terms: [
                Term(start: dc(2028, 1, 27), end: dc(2028, 4, 7)),
                Term(start: dc(2028, 4, 24), end: dc(2028, 7, 7)),
                Term(start: dc(2028, 7, 24), end: dc(2028, 9, 29)),
                Term(start: dc(2028, 10, 16), end: dc(2028, 12, 15)),
            ])
        case 2029:
            return SchoolYear(year: 2029, terms: [
                Term(start: dc(2029, 1, 29), end: dc(2029, 4, 13)),
                Term(start: dc(2029, 4, 30), end: dc(2029, 7, 6)),
                Term(start: dc(2029, 7, 23), end: dc(2029, 9, 28)),
                Term(start: dc(2029, 10, 15), end: dc(2029, 12, 17)),
            ])
        case 2030:
            return SchoolYear(year: 2030, terms: [
                Term(start: dc(2030, 1, 28), end: dc(2030, 4, 12)),
                Term(start: dc(2030, 4, 29), end: dc(2030, 7, 5)),
                Term(start: dc(2030, 7, 21), end: dc(2030, 9, 27)),
                Term(start: dc(2030, 10, 14), end: dc(2030, 12, 18)),
            ])
        default:
            return defaultTerms(year: year)
        }
    }

    private static func vicTerms(year: Int) -> SchoolYear {
        switch year {
        case 2024:
            return SchoolYear(year: 2024, terms: [
                Term(start: dc(2024, 1, 29), end: dc(2024, 3, 28)),
                Term(start: dc(2024, 4, 15), end: dc(2024, 6, 28)),
                Term(start: dc(2024, 7, 15), end: dc(2024, 9, 20)),
                Term(start: dc(2024, 10, 7), end: dc(2024, 12, 20)),
            ])
        case 2025:
            return SchoolYear(year: 2025, terms: [
                Term(start: dc(2025, 1, 28), end: dc(2025, 4, 4)),
                Term(start: dc(2025, 4, 22), end: dc(2025, 7, 4)),
                Term(start: dc(2025, 7, 21), end: dc(2025, 9, 19)),
                Term(start: dc(2025, 10, 6), end: dc(2025, 12, 19)),
            ])
        case 2026:
            return SchoolYear(year: 2026, terms: [
                Term(start: dc(2026, 1, 27), end: dc(2026, 3, 27)),
                Term(start: dc(2026, 4, 13), end: dc(2026, 6, 26)),
                Term(start: dc(2026, 7, 13), end: dc(2026, 9, 18)),
                Term(start: dc(2026, 10, 5), end: dc(2026, 12, 18)),
            ])
        default:
            return defaultTerms(year: year)
        }
    }

    private static func qldTerms(year: Int) -> SchoolYear {
        switch year {
        case 2024:
            return SchoolYear(year: 2024, terms: [
                Term(start: dc(2024, 1, 22), end: dc(2024, 3, 28)),
                Term(start: dc(2024, 4, 15), end: dc(2024, 6, 21)),
                Term(start: dc(2024, 7, 8), end: dc(2024, 9, 13)),
                Term(start: dc(2024, 9, 30), end: dc(2024, 12, 13)),
            ])
        case 2025:
            return SchoolYear(year: 2025, terms: [
                Term(start: dc(2025, 1, 27), end: dc(2025, 4, 4)),
                Term(start: dc(2025, 4, 22), end: dc(2025, 6, 27)),
                Term(start: dc(2025, 7, 14), end: dc(2025, 9, 19)),
                Term(start: dc(2025, 10, 7), end: dc(2025, 12, 12)),
            ])
        case 2026:
            return SchoolYear(year: 2026, terms: [
                Term(start: dc(2026, 1, 27), end: dc(2026, 3, 27)),
                Term(start: dc(2026, 4, 13), end: dc(2026, 6, 26)),
                Term(start: dc(2026, 7, 13), end: dc(2026, 9, 18)),
                Term(start: dc(2026, 10, 5), end: dc(2026, 12, 11)),
            ])
        default:
            return defaultTerms(year: year)
        }
    }

    private static func saTerms(year: Int) -> SchoolYear {
        switch year {
        case 2024:
            return SchoolYear(year: 2024, terms: [
                Term(start: dc(2024, 1, 29), end: dc(2024, 4, 12)),
                Term(start: dc(2024, 4, 29), end: dc(2024, 7, 5)),
                Term(start: dc(2024, 7, 22), end: dc(2024, 9, 27)),
                Term(start: dc(2024, 10, 14), end: dc(2024, 12, 13)),
            ])
        case 2025:
            return SchoolYear(year: 2025, terms: [
                Term(start: dc(2025, 1, 27), end: dc(2025, 4, 11)),
                Term(start: dc(2025, 4, 28), end: dc(2025, 7, 4)),
                Term(start: dc(2025, 7, 21), end: dc(2025, 9, 26)),
                Term(start: dc(2025, 10, 13), end: dc(2025, 12, 12)),
            ])
        case 2026:
            return SchoolYear(year: 2026, terms: [
                Term(start: dc(2026, 1, 27), end: dc(2026, 4, 2)),
                Term(start: dc(2026, 4, 20), end: dc(2026, 7, 3)),
                Term(start: dc(2026, 7, 20), end: dc(2026, 9, 25)),
                Term(start: dc(2026, 10, 12), end: dc(2026, 12, 11)),
            ])
        default:
            return defaultTerms(year: year)
        }
    }

    private static func waTerms(year: Int) -> SchoolYear {
        switch year {
        case 2024:
            return SchoolYear(year: 2024, terms: [
                Term(start: dc(2024, 1, 31), end: dc(2024, 3, 28)),
                Term(start: dc(2024, 4, 15), end: dc(2024, 6, 28)),
                Term(start: dc(2024, 7, 15), end: dc(2024, 9, 20)),
                Term(start: dc(2024, 10, 7), end: dc(2024, 12, 12)),
            ])
        case 2025:
            return SchoolYear(year: 2025, terms: [
                Term(start: dc(2025, 2, 3), end: dc(2025, 4, 11)),
                Term(start: dc(2025, 4, 28), end: dc(2025, 7, 4)),
                Term(start: dc(2025, 7, 21), end: dc(2025, 9, 19)),
                Term(start: dc(2025, 10, 7), end: dc(2025, 12, 11)),
            ])
        case 2026:
            return SchoolYear(year: 2026, terms: [
                Term(start: dc(2026, 2, 2), end: dc(2026, 4, 2)),
                Term(start: dc(2026, 4, 20), end: dc(2026, 7, 3)),
                Term(start: dc(2026, 7, 20), end: dc(2026, 9, 25)),
                Term(start: dc(2026, 10, 12), end: dc(2026, 12, 10)),
            ])
        default:
            return defaultTerms(year: year)
        }
    }

    private static func tasTerms(year: Int) -> SchoolYear {
        switch year {
        case 2024:
            return SchoolYear(year: 2024, terms: [
                Term(start: dc(2024, 2, 7), end: dc(2024, 4, 11)),
                Term(start: dc(2024, 4, 29), end: dc(2024, 7, 5)),
                Term(start: dc(2024, 7, 22), end: dc(2024, 9, 27)),
                Term(start: dc(2024, 10, 14), end: dc(2024, 12, 19)),
            ])
        case 2025:
            return SchoolYear(year: 2025, terms: [
                Term(start: dc(2025, 2, 5), end: dc(2025, 4, 11)),
                Term(start: dc(2025, 4, 28), end: dc(2025, 7, 4)),
                Term(start: dc(2025, 7, 21), end: dc(2025, 9, 26)),
                Term(start: dc(2025, 10, 13), end: dc(2025, 12, 18)),
            ])
        case 2026:
            return SchoolYear(year: 2026, terms: [
                Term(start: dc(2026, 2, 4), end: dc(2026, 4, 2)),
                Term(start: dc(2026, 4, 20), end: dc(2026, 7, 3)),
                Term(start: dc(2026, 7, 20), end: dc(2026, 9, 25)),
                Term(start: dc(2026, 10, 12), end: dc(2026, 12, 17)),
            ])
        default:
            return defaultTerms(year: year)
        }
    }

    private static func actTerms(year: Int) -> SchoolYear {
        switch year {
        case 2024:
            return SchoolYear(year: 2024, terms: [
                Term(start: dc(2024, 1, 29), end: dc(2024, 4, 12)),
                Term(start: dc(2024, 4, 29), end: dc(2024, 7, 5)),
                Term(start: dc(2024, 7, 22), end: dc(2024, 9, 27)),
                Term(start: dc(2024, 10, 14), end: dc(2024, 12, 17)),
            ])
        case 2025:
            return SchoolYear(year: 2025, terms: [
                Term(start: dc(2025, 2, 3), end: dc(2025, 4, 11)),
                Term(start: dc(2025, 4, 28), end: dc(2025, 7, 4)),
                Term(start: dc(2025, 7, 21), end: dc(2025, 9, 26)),
                Term(start: dc(2025, 10, 13), end: dc(2025, 12, 17)),
            ])
        case 2026:
            return SchoolYear(year: 2026, terms: [
                Term(start: dc(2026, 2, 2), end: dc(2026, 4, 2)),
                Term(start: dc(2026, 4, 20), end: dc(2026, 7, 3)),
                Term(start: dc(2026, 7, 20), end: dc(2026, 9, 25)),
                Term(start: dc(2026, 10, 12), end: dc(2026, 12, 16)),
            ])
        default:
            return defaultTerms(year: year)
        }
    }

    private static func ntTerms(year: Int) -> SchoolYear {
        switch year {
        case 2024:
            return SchoolYear(year: 2024, terms: [
                Term(start: dc(2024, 1, 29), end: dc(2024, 4, 5)),
                Term(start: dc(2024, 4, 15), end: dc(2024, 6, 21)),
                Term(start: dc(2024, 7, 15), end: dc(2024, 9, 20)),
                Term(start: dc(2024, 10, 7), end: dc(2024, 12, 12)),
            ])
        case 2025:
            return SchoolYear(year: 2025, terms: [
                Term(start: dc(2025, 1, 27), end: dc(2025, 4, 4)),
                Term(start: dc(2025, 4, 14), end: dc(2025, 6, 20)),
                Term(start: dc(2025, 7, 14), end: dc(2025, 9, 19)),
                Term(start: dc(2025, 10, 6), end: dc(2025, 12, 11)),
            ])
        case 2026:
            return SchoolYear(year: 2026, terms: [
                Term(start: dc(2026, 1, 27), end: dc(2026, 4, 2)),
                Term(start: dc(2026, 4, 13), end: dc(2026, 6, 19)),
                Term(start: dc(2026, 7, 13), end: dc(2026, 9, 18)),
                Term(start: dc(2026, 10, 5), end: dc(2026, 12, 10)),
            ])
        default:
            return defaultTerms(year: year)
        }
    }

    /// Provides a reasonable default set of school terms for years without explicit data.
    private static func defaultTerms(year: Int) -> SchoolYear {
        return SchoolYear(year: year, terms: [
            Term(start: dc(year, 1, 28), end: dc(year, 4, 10)),
            Term(start: dc(year, 4, 27), end: dc(year, 7, 4)),
            Term(start: dc(year, 7, 20), end: dc(year, 9, 25)),
            Term(start: dc(year, 10, 12), end: dc(year, 12, 16)),
        ])
    }

    // MARK: - DateComponents Helper

    private static func dc(_ year: Int, _ month: Int, _ day: Int) -> DateComponents {
        return DateComponents(year: year, month: month, day: day)
    }
}
