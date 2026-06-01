// PublicHolidayTests.swift
// CanIParkTests

import XCTest
@testable import CanIPark

final class PublicHolidayTests: XCTestCase {

    // MARK: - Calendar & Date Helpers

    private var ausCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return cal
    }

    private func makeDate(year: Int = 2026, month: Int, day: Int, hour: Int = 10, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute; comps.second = 0
        comps.timeZone = TimeZone(identifier: "Australia/Sydney")
        return ausCalendar.date(from: comps)!
    }

    // MARK: - TimeWindow.contains with Public Holiday Flag

    func testWindowDoesNotApplyOnPublicHoliday() {
        let window = TimeWindow(
            startTime: TimeOfDay(hour: 8, minute: 0),
            endTime: TimeOfDay(hour: 18, minute: 0),
            daysOfWeek: DayOfWeek.weekdays,
            schoolDaysOnly: false,
            publicHolidayBehavior: .doesNotApply
        )
        // Monday at 10am, marked as public holiday
        let date = makeDate(month: 6, day: 1, hour: 10)
        XCTAssertFalse(window.contains(date: date, calendar: ausCalendar, isPublicHoliday: true))
    }

    func testWindowAppliesOnNormalDay() {
        let window = TimeWindow(
            startTime: TimeOfDay(hour: 8, minute: 0),
            endTime: TimeOfDay(hour: 18, minute: 0),
            daysOfWeek: DayOfWeek.weekdays,
            schoolDaysOnly: false,
            publicHolidayBehavior: .doesNotApply
        )
        let date = makeDate(month: 6, day: 1, hour: 10)
        XCTAssertTrue(window.contains(date: date, calendar: ausCalendar, isPublicHoliday: false))
    }

    func testPublicHolidayOnlyWindowAppliesOnHoliday() {
        let window = TimeWindow(
            startTime: TimeOfDay(hour: 8, minute: 0),
            endTime: TimeOfDay(hour: 18, minute: 0),
            daysOfWeek: DayOfWeek.allDays,
            schoolDaysOnly: false,
            publicHolidayBehavior: .publicHolidayOnly
        )
        let date = makeDate(month: 6, day: 1, hour: 10)
        XCTAssertTrue(window.contains(date: date, calendar: ausCalendar, isPublicHoliday: true))
    }

    func testPublicHolidayOnlyWindowDoesNotApplyOnNormalDay() {
        let window = TimeWindow(
            startTime: TimeOfDay(hour: 8, minute: 0),
            endTime: TimeOfDay(hour: 18, minute: 0),
            daysOfWeek: DayOfWeek.allDays,
            schoolDaysOnly: false,
            publicHolidayBehavior: .publicHolidayOnly
        )
        let date = makeDate(month: 6, day: 1, hour: 10)
        XCTAssertFalse(window.contains(date: date, calendar: ausCalendar, isPublicHoliday: false))
    }

    func testPublicHolidayAppliesBehaviorOnHoliday() {
        let window = TimeWindow(
            startTime: TimeOfDay(hour: 8, minute: 0),
            endTime: TimeOfDay(hour: 18, minute: 0),
            daysOfWeek: DayOfWeek.weekdays,
            schoolDaysOnly: false,
            publicHolidayBehavior: .applies
        )
        let date = makeDate(month: 6, day: 1, hour: 10)
        XCTAssertTrue(window.contains(date: date, calendar: ausCalendar, isPublicHoliday: true))
    }

    func testUnspecifiedBehaviorOnHoliday() {
        let window = TimeWindow(
            startTime: TimeOfDay(hour: 8, minute: 0),
            endTime: TimeOfDay(hour: 18, minute: 0),
            daysOfWeek: DayOfWeek.weekdays,
            schoolDaysOnly: false,
            publicHolidayBehavior: .unspecified
        )
        let date = makeDate(month: 6, day: 1, hour: 10)
        // Unspecified means the window still applies regardless of holiday
        XCTAssertTrue(window.contains(date: date, calendar: ausCalendar, isPublicHoliday: true))
    }

    // MARK: - ParkingRestriction.isActive with Public Holiday

    func testRestrictionNotActiveOnPublicHolidayWhenExcluded() {
        let restriction = ParkingRestriction(
            category: .noStopping, maxStayMinutes: nil,
            timeWindows: [TimeWindow(
                startTime: TimeOfDay(hour: 7, minute: 0),
                endTime: TimeOfDay(hour: 9, minute: 0),
                daysOfWeek: DayOfWeek.weekdays,
                schoolDaysOnly: false,
                publicHolidayBehavior: .doesNotApply
            )],
            paymentType: .none, exemptions: [], arrowDirection: .none,
            rawText: "NO STOPPING 7AM-9AM MON-FRI EXCEPT PUBLIC HOLIDAYS",
            confidence: 0.95
        )
        let date = makeDate(month: 6, day: 1, hour: 8)
        XCTAssertFalse(restriction.isActive(at: date, calendar: ausCalendar, isPublicHoliday: true))
    }

    func testRestrictionActiveOnPublicHolidayWhenApplies() {
        let restriction = ParkingRestriction(
            category: .noStopping, maxStayMinutes: nil,
            timeWindows: [TimeWindow(
                startTime: TimeOfDay(hour: 7, minute: 0),
                endTime: TimeOfDay(hour: 9, minute: 0),
                daysOfWeek: DayOfWeek.weekdays,
                schoolDaysOnly: false,
                publicHolidayBehavior: .applies
            )],
            paymentType: .none, exemptions: [], arrowDirection: .none,
            rawText: "NO STOPPING 7AM-9AM MON-FRI PUBLIC HOLIDAYS",
            confidence: 0.95
        )
        let date = makeDate(month: 6, day: 1, hour: 8)
        XCTAssertTrue(restriction.isActive(at: date, calendar: ausCalendar, isPublicHoliday: true))
    }

    // MARK: - Decision Engine with Public Holiday

    func testEngineNoStoppingExcludedOnPublicHoliday() {
        let decision = ParkingDecisionEngine.decideFromText(
            "NO STOPPING 7AM-9AM MON-FRI EXCEPT PUBLIC HOLIDAYS",
            dateTime: makeDate(month: 6, day: 1, hour: 8),
            isPublicHoliday: true
        )
        XCTAssertEqual(decision.canPark, .yes)
    }

    func testEngineNoStoppingNotExcludedOnPublicHoliday() {
        let decision = ParkingDecisionEngine.decideFromText(
            "NO STOPPING 7AM-9AM MON-FRI",
            dateTime: makeDate(month: 6, day: 1, hour: 8),
            isPublicHoliday: true
        )
        XCTAssertEqual(decision.canPark, .no)
    }

    func testEngineClearwayExcludedOnPublicHoliday() {
        let decision = ParkingDecisionEngine.decideFromText(
            "CLEARWAY 6AM-10AM MON-FRI NOT ON PUBLIC HOLIDAYS",
            dateTime: makeDate(month: 6, day: 1, hour: 7),
            isPublicHoliday: true
        )
        XCTAssertEqual(decision.canPark, .yes)
    }

    func testEngineTimedParkingExcludedOnPublicHoliday() {
        let decision = ParkingDecisionEngine.decideFromText(
            "2P 8AM-6PM MON-FRI EXCL. PUBLIC HOLIDAYS",
            dateTime: makeDate(month: 6, day: 1, hour: 10),
            isPublicHoliday: true
        )
        // Excluded on public holiday -> unrestricted -> can park, no time limit
        XCTAssertEqual(decision.canPark, .yes)
        XCTAssertNil(decision.maxStayMinutes)
    }

    // MARK: - Known Australian Public Holidays (Date-Based)

    func testNewYearsDay() {
        // Jan 1 is always a public holiday
        let date = makeDate(year: 2026, month: 1, day: 1, hour: 10)
        let decision = ParkingDecisionEngine.decideFromText(
            "NO PARKING 8AM-6PM MON-FRI EXCEPT PUBLIC HOLIDAYS",
            dateTime: date, isPublicHoliday: true
        )
        XCTAssertEqual(decision.canPark, .yes)
    }

    func testAustraliaDay() {
        // Jan 26
        let date = makeDate(year: 2026, month: 1, day: 26, hour: 10)
        let decision = ParkingDecisionEngine.decideFromText(
            "NO PARKING 8AM-6PM EXCEPT PUBLIC HOLIDAYS",
            dateTime: date, isPublicHoliday: true
        )
        XCTAssertEqual(decision.canPark, .yes)
    }

    func testAnzacDay() {
        // April 25
        let date = makeDate(year: 2026, month: 4, day: 25, hour: 10)
        let decision = ParkingDecisionEngine.decideFromText(
            "2P METER 8AM-6PM MON-FRI EXCEPT PUBLIC HOLIDAYS",
            dateTime: date, isPublicHoliday: true
        )
        XCTAssertEqual(decision.canPark, .yes)
        XCTAssertEqual(decision.paymentStatus, .free)
    }

    func testChristmasDay() {
        // Dec 25
        let date = makeDate(year: 2026, month: 12, day: 25, hour: 10)
        let decision = ParkingDecisionEngine.decideFromText(
            "NO STOPPING 7AM-9AM MON-FRI NOT ON PUBLIC HOLIDAYS",
            dateTime: date, isPublicHoliday: true
        )
        XCTAssertEqual(decision.canPark, .yes)
    }

    func testBoxingDay() {
        // Dec 26
        let date = makeDate(year: 2026, month: 12, day: 26, hour: 10)
        let decision = ParkingDecisionEngine.decideFromText(
            "2P 8AM-6PM MON-FRI EXCEPT PUBLIC HOLIDAYS",
            dateTime: date, isPublicHoliday: true
        )
        XCTAssertEqual(decision.canPark, .yes)
    }

    // MARK: - Edge Cases

    func testPublicHolidayFlagFalseDoesNotAffect() {
        let decision = ParkingDecisionEngine.decideFromText(
            "NO STOPPING 7AM-9AM MON-FRI EXCEPT PUBLIC HOLIDAYS",
            dateTime: makeDate(month: 6, day: 1, hour: 8),
            isPublicHoliday: false
        )
        // Not a holiday, so the restriction applies normally
        XCTAssertEqual(decision.canPark, .no)
    }

    func testPublicHolidayOnlyNoParkingOnNormalDay() {
        let decision = ParkingDecisionEngine.decideFromText(
            "NO PARKING 8AM-6PM PUBLIC HOLIDAYS ONLY",
            dateTime: makeDate(month: 6, day: 1, hour: 10),
            isPublicHoliday: false
        )
        // Only applies on holidays, today is not one
        XCTAssertEqual(decision.canPark, .yes)
    }

    func testMultipleRestrictionsWithDifferentHolidayBehavior() {
        // This tests that parsing two panels with different holiday behaviors works
        let text = "NO STOPPING 7AM-9AM MON-FRI EXCEPT PUBLIC HOLIDAYS\n\n2P 8AM-6PM MON-FRI"
        let restrictions = SignTextParser.parse(ocrText: text)
        XCTAssertEqual(restrictions.count, 2)

        // On a public holiday at 8am, the no stopping should not apply
        let input = ParkingDecisionEngine.Input(
            restrictions: restrictions,
            dateTime: makeDate(month: 6, day: 1, hour: 8),
            calendar: ausCalendar,
            isPublicHoliday: true
        )
        let decision = ParkingDecisionEngine.decide(input: input)
        // The no stopping does not apply (holiday excluded), but 2P does apply (no holiday spec)
        // 2P at 8am on Mon-Fri should be yes with time limit
        XCTAssertEqual(decision.canPark, .yes)
        XCTAssertEqual(decision.maxStayMinutes, 120)
    }
}
