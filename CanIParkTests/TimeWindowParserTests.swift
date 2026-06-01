// TimeWindowParserTests.swift
// CanIParkTests

import XCTest
@testable import CanIPark

final class TimeWindowParserTests: XCTestCase {

    // MARK: - Helper

    private func parseWindows(_ text: String) -> [TimeWindow] {
        return TimeWindowParser.parse(from: text)
    }

    private func parseSingle(_ text: String) -> TimeWindow? {
        return parseWindows(text).first
    }

    // MARK: - AM/PM Time Ranges

    func testParseAMtoPM() {
        let w = parseSingle("8AM-6PM")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.startTime, TimeOfDay(hour: 8, minute: 0))
        XCTAssertEqual(w?.endTime, TimeOfDay(hour: 18, minute: 0))
    }

    func testParseAMtoAM() {
        let w = parseSingle("6AM-11AM")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.startTime, TimeOfDay(hour: 6, minute: 0))
        XCTAssertEqual(w?.endTime, TimeOfDay(hour: 11, minute: 0))
    }

    func testParsePMtoPM() {
        let w = parseSingle("1PM-5PM")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.startTime, TimeOfDay(hour: 13, minute: 0))
        XCTAssertEqual(w?.endTime, TimeOfDay(hour: 17, minute: 0))
    }

    func testParse12AMto12PM() {
        let w = parseSingle("12AM-12PM")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.startTime, TimeOfDay(hour: 0, minute: 0))
        XCTAssertEqual(w?.endTime, TimeOfDay(hour: 12, minute: 0))
    }

    func testParse12PMto12AM() {
        let w = parseSingle("12PM-12AM")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.startTime, TimeOfDay(hour: 12, minute: 0))
        XCTAssertEqual(w?.endTime, TimeOfDay(hour: 0, minute: 0))
    }

    func testParseTimeWithMinutes() {
        let w = parseSingle("8:30AM-5:30PM")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.startTime, TimeOfDay(hour: 8, minute: 30))
        XCTAssertEqual(w?.endTime, TimeOfDay(hour: 17, minute: 30))
    }

    func testParseTimeWithDotSeparator() {
        let w = parseSingle("8.30AM-5.30PM")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.startTime, TimeOfDay(hour: 8, minute: 30))
        XCTAssertEqual(w?.endTime, TimeOfDay(hour: 17, minute: 30))
    }

    func testParseTimeWithSpaces() {
        let w = parseSingle("8 AM - 6 PM")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.startTime, TimeOfDay(hour: 8, minute: 0))
        XCTAssertEqual(w?.endTime, TimeOfDay(hour: 18, minute: 0))
    }

    func testParseLowercaseAMPM() {
        let w = parseSingle("8am-6pm")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.startTime, TimeOfDay(hour: 8, minute: 0))
        XCTAssertEqual(w?.endTime, TimeOfDay(hour: 18, minute: 0))
    }

    // MARK: - Military Time

    func testParseMilitaryTime() {
        let w = parseSingle("0800-1800")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.startTime, TimeOfDay(hour: 8, minute: 0))
        XCTAssertEqual(w?.endTime, TimeOfDay(hour: 18, minute: 0))
    }

    func testParseMilitaryTimeMidnight() {
        let w = parseSingle("0000-2359")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.startTime, TimeOfDay(hour: 0, minute: 0))
        XCTAssertEqual(w?.endTime, TimeOfDay(hour: 23, minute: 59))
    }

    func testParseMilitaryTimeWithDash() {
        let w = parseSingle("0630-0930")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.startTime, TimeOfDay(hour: 6, minute: 30))
        XCTAssertEqual(w?.endTime, TimeOfDay(hour: 9, minute: 30))
    }

    // MARK: - Day Ranges

    func testParseMonToFri() {
        let w = parseSingle("8AM-6PM MON-FRI")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.daysOfWeek, DayOfWeek.weekdays)
    }

    func testParseSatToSun() {
        let w = parseSingle("8AM-6PM SAT-SUN")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.daysOfWeek, DayOfWeek.weekend)
    }

    func testParseMonToSat() {
        let w = parseSingle("8AM-6PM MON-SAT")
        XCTAssertNotNil(w)
        let expected: Set<DayOfWeek> = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
        XCTAssertEqual(w?.daysOfWeek, expected)
    }

    func testParseSingleDay() {
        let w = parseSingle("8AM-6PM SAT")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.daysOfWeek, [.saturday])
    }

    func testParseMultipleIndividualDays() {
        let w = parseSingle("8AM-6PM MON WED FRI")
        XCTAssertNotNil(w)
        XCTAssertTrue(w?.daysOfWeek.contains(.monday) ?? false)
        XCTAssertTrue(w?.daysOfWeek.contains(.wednesday) ?? false)
        XCTAssertTrue(w?.daysOfWeek.contains(.friday) ?? false)
    }

    func testParseDayAbbreviationTUES() {
        let w = parseSingle("8AM-6PM TUES-THURS")
        XCTAssertNotNil(w)
        let expected: Set<DayOfWeek> = [.tuesday, .wednesday, .thursday]
        XCTAssertEqual(w?.daysOfWeek, expected)
    }

    func testParseFullDayNames() {
        let w = parseSingle("8AM-6PM MONDAY")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.daysOfWeek, [.monday])
    }

    // MARK: - No Time or Day (All Day / Every Day)

    func testParseNoDays_DefaultsToAllDays() {
        let w = parseSingle("8AM-6PM")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.daysOfWeek, DayOfWeek.allDays)
    }

    func testParseNoTimeNoDay_ReturnsEmpty() {
        let windows = parseWindows("HELLO WORLD")
        XCTAssertTrue(windows.isEmpty)
    }

    func testParseDaysOnly_AllDayWindow() {
        let w = parseSingle("MON-FRI")
        XCTAssertNotNil(w)
        XCTAssertTrue(w?.isAllDay ?? false)
        XCTAssertEqual(w?.daysOfWeek, DayOfWeek.weekdays)
    }

    // MARK: - School Days

    func testParseSchoolDays() {
        let w = parseSingle("8AM-9AM SCHOOL DAYS")
        XCTAssertNotNil(w)
        XCTAssertTrue(w?.schoolDaysOnly ?? false)
    }

    func testParseSchoolDay() {
        let w = parseSingle("8AM-9AM SCHOOL DAY")
        XCTAssertNotNil(w)
        XCTAssertTrue(w?.schoolDaysOnly ?? false)
    }

    func testParseNoSchoolDays() {
        let w = parseSingle("8AM-6PM MON-FRI")
        XCTAssertNotNil(w)
        XCTAssertFalse(w?.schoolDaysOnly ?? true)
    }

    // MARK: - Public Holiday Behavior

    func testParseNotOnPublicHolidays() {
        let w = parseSingle("8AM-6PM NOT ON PUBLIC HOLIDAYS")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.publicHolidayBehavior, .doesNotApply)
    }

    func testParseExceptPublicHolidays() {
        let w = parseSingle("8AM-6PM EXCEPT PUBLIC HOLIDAYS")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.publicHolidayBehavior, .doesNotApply)
    }

    func testParseExclPublicHolidays() {
        let w = parseSingle("8AM-6PM EXCL. PUBLIC HOLIDAYS")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.publicHolidayBehavior, .doesNotApply)
    }

    func testParsePublicHolidaysOnly() {
        let w = parseSingle("8AM-6PM PUBLIC HOLIDAYS ONLY")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.publicHolidayBehavior, .publicHolidayOnly)
    }

    func testParsePublicHolidayApplies() {
        let w = parseSingle("8AM-6PM PUBLIC HOLIDAYS")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.publicHolidayBehavior, .applies)
    }

    func testParseNoPublicHolidayMention() {
        let w = parseSingle("8AM-6PM MON-FRI")
        XCTAssertNotNil(w)
        XCTAssertEqual(w?.publicHolidayBehavior, .unspecified)
    }

    // MARK: - Multiple Time Ranges

    func testParseMultipleTimeRanges() {
        // Some signs have morning and afternoon windows
        let windows = parseWindows("7AM-9AM 4PM-6PM MON-FRI")
        XCTAssertEqual(windows.count, 2)
        XCTAssertEqual(windows[0].startTime, TimeOfDay(hour: 7, minute: 0))
        XCTAssertEqual(windows[0].endTime, TimeOfDay(hour: 9, minute: 0))
        XCTAssertEqual(windows[1].startTime, TimeOfDay(hour: 16, minute: 0))
        XCTAssertEqual(windows[1].endTime, TimeOfDay(hour: 18, minute: 0))
    }

    // MARK: - TimeWindow Properties

    func testIsAllDay() {
        let w = TimeWindow(startTime: .midnight, endTime: .endOfDay,
                           daysOfWeek: DayOfWeek.allDays, schoolDaysOnly: false,
                           publicHolidayBehavior: .unspecified)
        XCTAssertTrue(w.isAllDay)
    }

    func testIsNotAllDay() {
        let w = TimeWindow(startTime: TimeOfDay(hour: 8, minute: 0),
                           endTime: TimeOfDay(hour: 18, minute: 0),
                           daysOfWeek: DayOfWeek.allDays, schoolDaysOnly: false,
                           publicHolidayBehavior: .unspecified)
        XCTAssertFalse(w.isAllDay)
    }

    func testIsEveryDay() {
        let w = TimeWindow.always
        XCTAssertTrue(w.isEveryDay)
    }

    func testIsNotEveryDay() {
        let w = TimeWindow(startTime: .midnight, endTime: .endOfDay,
                           daysOfWeek: DayOfWeek.weekdays, schoolDaysOnly: false,
                           publicHolidayBehavior: .unspecified)
        XCTAssertFalse(w.isEveryDay)
    }
}
