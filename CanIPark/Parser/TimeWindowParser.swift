// TimeWindowParser.swift
// CanIPark
//
// Parses time and day expressions from Australian parking sign OCR text
// into structured TimeWindow objects.

import Foundation

struct TimeWindowParser {

    static func parse(from text: String) -> [TimeWindow] {
        let normalised = text.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let timeRanges = parseTimeRanges(from: normalised)
        let days = parseDays(from: normalised)
        let schoolDaysOnly = parseSchoolDays(from: normalised)
        let publicHolidayBehavior = parsePublicHolidayBehavior(from: normalised)

        if timeRanges.isEmpty && days == nil && !schoolDaysOnly && publicHolidayBehavior == .unspecified {
            return []
        }

        let effectiveDays = days ?? DayOfWeek.allDays

        if timeRanges.isEmpty {
            return [TimeWindow(
                startTime: .midnight, endTime: .endOfDay,
                daysOfWeek: effectiveDays, schoolDaysOnly: schoolDaysOnly,
                publicHolidayBehavior: publicHolidayBehavior
            )]
        }

        return timeRanges.map { range in
            TimeWindow(
                startTime: range.start, endTime: range.end,
                daysOfWeek: effectiveDays, schoolDaysOnly: schoolDaysOnly,
                publicHolidayBehavior: publicHolidayBehavior
            )
        }
    }

    // MARK: - Time Range Parsing

    private static func parseTimeRanges(from text: String) -> [(start: TimeOfDay, end: TimeOfDay)] {
        var results: [(start: TimeOfDay, end: TimeOfDay)] = []

        let ampmPattern = #"(\d{1,2})[:\.]?(\d{2})?\s*(AM|PM)\s*[-–—TO]+\s*(\d{1,2})[:\.]?(\d{2})?\s*(AM|PM)"#
        if let regex = try? NSRegularExpression(pattern: ampmPattern, options: .caseInsensitive) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                let startHourStr = nsText.substring(with: match.range(at: 1))
                let startMinStr = match.range(at: 2).location != NSNotFound ? nsText.substring(with: match.range(at: 2)) : "0"
                let startPeriod = nsText.substring(with: match.range(at: 3)).uppercased()
                let endHourStr = nsText.substring(with: match.range(at: 4))
                let endMinStr = match.range(at: 5).location != NSNotFound ? nsText.substring(with: match.range(at: 5)) : "0"
                let endPeriod = nsText.substring(with: match.range(at: 6)).uppercased()

                if let sh = Int(startHourStr), let sm = Int(startMinStr),
                   let eh = Int(endHourStr), let em = Int(endMinStr) {
                    results.append((
                        start: convertTo24Hour(hour: sh, minute: sm, period: startPeriod),
                        end: convertTo24Hour(hour: eh, minute: em, period: endPeriod)
                    ))
                }
            }
        }

        if results.isEmpty {
            let milPattern = #"(\d{4})\s*[-–—]\s*(\d{4})"#
            if let regex = try? NSRegularExpression(pattern: milPattern) {
                let nsText = text as NSString
                let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
                for match in matches {
                    let startStr = nsText.substring(with: match.range(at: 1))
                    let endStr = nsText.substring(with: match.range(at: 2))
                    if let sv = Int(startStr), let ev = Int(endStr) {
                        let sh = sv / 100, sm = sv % 100, eh = ev / 100, em = ev % 100
                        if sh < 24 && sm < 60 && eh < 24 && em < 60 {
                            results.append((
                                start: TimeOfDay(hour: sh, minute: sm),
                                end: TimeOfDay(hour: eh, minute: em)
                            ))
                        }
                    }
                }
            }
        }

        return results
    }

    private static func convertTo24Hour(hour: Int, minute: Int, period: String) -> TimeOfDay {
        var h = hour
        if period == "AM" { if h == 12 { h = 0 } }
        else { if h != 12 { h += 12 } }
        return TimeOfDay(hour: h, minute: minute)
    }

    // MARK: - Day Parsing

    private static func parseDays(from text: String) -> Set<DayOfWeek>? {
        let rangePattern = #"(MON|TUE|TUES|WED|THU|THUR|THURS|FRI|SAT|SUN)\s*[-–—TO]+\s*(MON|TUE|TUES|WED|THU|THUR|THURS|FRI|SAT|SUN)"#
        var foundDays: Set<DayOfWeek> = []
        var foundAny = false

        if let regex = try? NSRegularExpression(pattern: rangePattern, options: .caseInsensitive) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches {
                let startDayStr = nsText.substring(with: match.range(at: 1)).uppercased()
                let endDayStr = nsText.substring(with: match.range(at: 2)).uppercased()
                if let startDay = resolveDayAbbreviation(startDayStr),
                   let endDay = resolveDayAbbreviation(endDayStr) {
                    foundDays.formUnion(dayRange(from: startDay, to: endDay))
                    foundAny = true
                }
            }
        }

        if !foundAny {
            let singlePattern = #"\b(MON|MONDAY|TUE|TUES|TUESDAY|WED|WEDNESDAY|THU|THUR|THURS|THURSDAY|FRI|FRIDAY|SAT|SATURDAY|SUN|SUNDAY)\b"#
            if let regex = try? NSRegularExpression(pattern: singlePattern, options: .caseInsensitive) {
                let nsText = text as NSString
                let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
                for match in matches {
                    let dayStr = nsText.substring(with: match.range(at: 1)).uppercased()
                    if let day = resolveDayAbbreviation(dayStr) {
                        foundDays.insert(day)
                        foundAny = true
                    }
                }
            }
        }

        return foundAny ? foundDays : nil
    }

    private static func resolveDayAbbreviation(_ str: String) -> DayOfWeek? {
        switch str.prefix(3).uppercased() {
        case "MON": return .monday
        case "TUE": return .tuesday
        case "WED": return .wednesday
        case "THU": return .thursday
        case "FRI": return .friday
        case "SAT": return .saturday
        case "SUN": return .sunday
        default: return nil
        }
    }

    private static func dayRange(from start: DayOfWeek, to end: DayOfWeek) -> Set<DayOfWeek> {
        let ordered: [DayOfWeek] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
        guard let startIdx = ordered.firstIndex(of: start),
              let endIdx = ordered.firstIndex(of: end) else { return [] }

        var result: Set<DayOfWeek> = []
        if startIdx <= endIdx {
            for i in startIdx...endIdx { result.insert(ordered[i]) }
        } else {
            for i in startIdx..<ordered.count { result.insert(ordered[i]) }
            for i in 0...endIdx { result.insert(ordered[i]) }
        }
        return result
    }

    // MARK: - Special Day Parsing

    private static func parseSchoolDays(from text: String) -> Bool {
        text.range(of: #"SCHOOL\s*DAYS?"#, options: .regularExpression) != nil
    }

    private static func parsePublicHolidayBehavior(from text: String) -> PublicHolidayBehavior {
        if text.range(of: #"(NOT\s+ON|EXCEPT|EXCL\.?)\s+PUBLIC\s+HOLIDAYS?"#, options: .regularExpression) != nil {
            return .doesNotApply
        }
        if text.range(of: #"PUBLIC\s+HOLIDAYS?\s+ONLY"#, options: .regularExpression) != nil {
            return .publicHolidayOnly
        }
        if text.range(of: #"PUBLIC\s+HOLIDAYS?"#, options: .regularExpression) != nil {
            return .applies
        }
        return .unspecified
    }
}
