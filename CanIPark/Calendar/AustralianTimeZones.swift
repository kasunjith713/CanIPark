// AustralianTimeZones.swift
// CanIPark

import Foundation

// MARK: - Australian Time Zone Helpers

/// Provides time zone utilities for Australian states and territories.
struct AustralianTimeZones {

    // MARK: - Standard Time Zones (no DST)

    /// Australian Eastern Standard Time (UTC+10) — QLD year-round; NSW/VIC/TAS/ACT in winter.
    static let aest = TimeZone(identifier: "Australia/Brisbane")!

    /// Australian Central Standard Time (UTC+9:30) — NT year-round; SA in winter.
    static let acst = TimeZone(identifier: "Australia/Darwin")!

    /// Australian Western Standard Time (UTC+8) — WA year-round.
    static let awst = TimeZone(identifier: "Australia/Perth")!

    // MARK: - DST-Aware Time Zones

    /// Sydney time (AEST/AEDT) — observes DST.
    static let sydney = TimeZone(identifier: "Australia/Sydney")!

    /// Melbourne time (AEST/AEDT) — observes DST.
    static let melbourne = TimeZone(identifier: "Australia/Melbourne")!

    /// Hobart time (AEST/AEDT) — observes DST.
    static let hobart = TimeZone(identifier: "Australia/Hobart")!

    /// Adelaide time (ACST/ACDT) — observes DST.
    static let adelaide = TimeZone(identifier: "Australia/Adelaide")!

    /// Brisbane time (AEST) — does not observe DST.
    static let brisbane = TimeZone(identifier: "Australia/Brisbane")!

    /// Perth time (AWST) — does not observe DST.
    static let perth = TimeZone(identifier: "Australia/Perth")!

    /// Darwin time (ACST) — does not observe DST.
    static let darwin = TimeZone(identifier: "Australia/Darwin")!

    // MARK: - Lookup

    /// Returns the appropriate time zone for a given state. The returned time zone is DST-aware
    /// where applicable (i.e., using the IANA identifier that includes DST transitions).
    static func timeZone(for state: AustralianState) -> TimeZone {
        return state.timeZone
    }

    /// Returns a `Calendar` configured for the given state's time zone.
    static func calendar(for state: AustralianState) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone(for: state)
        return cal
    }

    /// Returns the current `Date` expressed in the given state's local time zone.
    /// This is primarily useful for display — `Date` itself is always UTC.
    static func now(in state: AustralianState) -> Date {
        return Date()
    }

    /// Returns the current UTC offset in hours (as a `Double`) for the given state,
    /// accounting for DST if applicable.
    static func currentUTCOffset(for state: AustralianState, at date: Date = Date()) -> Double {
        let tz = timeZone(for: state)
        let offsetSeconds = tz.secondsFromGMT(for: date)
        return Double(offsetSeconds) / 3600.0
    }

    /// Returns `true` if the given state is currently in daylight saving time.
    static func isDST(for state: AustralianState, at date: Date = Date()) -> Bool {
        guard state.observesDST else { return false }
        let tz = timeZone(for: state)
        return tz.isDaylightSavingTime(for: date)
    }

    /// Returns the abbreviated time zone name (e.g., "AEST", "AEDT") for the given state
    /// at the specified date.
    static func abbreviation(for state: AustralianState, at date: Date = Date()) -> String {
        let tz = timeZone(for: state)
        return tz.abbreviation(for: date) ?? tz.abbreviation() ?? state.abbreviation
    }

    // MARK: - Formatting

    /// Returns a `DateFormatter` configured for the given state's time zone.
    static func dateFormatter(for state: AustralianState, dateStyle: DateFormatter.Style = .medium,
                              timeStyle: DateFormatter.Style = .short) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone(for: state)
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        formatter.locale = Locale(identifier: "en_AU")
        return formatter
    }

    /// Returns a human-readable string of the current time in the given state.
    static func formattedCurrentTime(for state: AustralianState) -> String {
        let formatter = dateFormatter(for: state, dateStyle: .none, timeStyle: .short)
        return formatter.string(from: Date())
    }
}
