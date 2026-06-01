// ParkingDecisionEngineTests.swift
// CanIParkTests

import XCTest
@testable import CanIPark

final class ParkingDecisionEngineTests: XCTestCase {

    // MARK: - Calendar & Date Helpers

    /// Returns a Calendar fixed to the Australia/Sydney timezone.
    private var ausCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Sydney")!
        return cal
    }

    /// Build a Date for a specific weekday and time in 2026.
    /// weekday: 1 = Sunday ... 7 = Saturday (Calendar convention)
    private func makeDate(year: Int = 2026, month: Int = 6, day: Int, hour: Int, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute; comps.second = 0
        comps.timeZone = TimeZone(identifier: "Australia/Sydney")
        return ausCalendar.date(from: comps)!
    }

    // June 2026:
    // Mon 1, Tue 2, Wed 3, Thu 4, Fri 5, Sat 6, Sun 7
    // Mon 8, ... Sat 13, Sun 14

    /// Monday June 1 2026 at the given hour
    private func monday(_ hour: Int, _ minute: Int = 0) -> Date { makeDate(day: 1, hour: hour, minute: minute) }
    /// Saturday June 6 2026
    private func saturday(_ hour: Int, _ minute: Int = 0) -> Date { makeDate(day: 6, hour: hour, minute: minute) }
    /// Sunday June 7 2026
    private func sunday(_ hour: Int, _ minute: Int = 0) -> Date { makeDate(day: 7, hour: hour, minute: minute) }

    // MARK: - Timed Parking During Active Hours

    func testTimedParking2PDuringHours() {
        let decision = ParkingDecisionEngine.decideFromText("2P 8AM-6PM MON-FRI", dateTime: monday(10))
        XCTAssertEqual(decision.canPark, .yes)
        XCTAssertEqual(decision.maxStayMinutes, 120)
    }

    func testTimedParking1PDuringHours() {
        let decision = ParkingDecisionEngine.decideFromText("1P 8AM-6PM MON-FRI", dateTime: monday(14))
        XCTAssertEqual(decision.canPark, .yes)
        XCTAssertEqual(decision.maxStayMinutes, 60)
    }

    func testTimedParking4PDuringHours() {
        let decision = ParkingDecisionEngine.decideFromText("4P 8AM-6PM MON-FRI", dateTime: monday(9))
        XCTAssertEqual(decision.canPark, .yes)
        XCTAssertEqual(decision.maxStayMinutes, 240)
    }

    func testTimedParkingHalfPDuringHours() {
        let decision = ParkingDecisionEngine.decideFromText("1/2P 8AM-6PM MON-FRI", dateTime: monday(12))
        XCTAssertEqual(decision.canPark, .yes)
        XCTAssertEqual(decision.maxStayMinutes, 30)
    }

    // MARK: - Timed Parking Outside Active Hours

    func testTimedParkingOutsideHoursEvening() {
        let decision = ParkingDecisionEngine.decideFromText("2P 8AM-6PM MON-FRI", dateTime: monday(19))
        XCTAssertEqual(decision.canPark, .yes)
        XCTAssertNil(decision.maxStayMinutes)
    }

    func testTimedParkingOutsideHoursWeekend() {
        let decision = ParkingDecisionEngine.decideFromText("2P 8AM-6PM MON-FRI", dateTime: saturday(10))
        XCTAssertEqual(decision.canPark, .yes)
        XCTAssertNil(decision.maxStayMinutes)
    }

    func testTimedParkingOutsideHoursEarlyMorning() {
        let decision = ParkingDecisionEngine.decideFromText("2P 8AM-6PM MON-FRI", dateTime: monday(6))
        XCTAssertEqual(decision.canPark, .yes)
        XCTAssertNil(decision.maxStayMinutes)
    }

    // MARK: - No Stopping

    func testNoStoppingDuringHours() {
        let decision = ParkingDecisionEngine.decideFromText("NO STOPPING 7AM-9AM MON-FRI", dateTime: monday(8))
        XCTAssertEqual(decision.canPark, .no)
    }

    func testNoStoppingOutsideHours() {
        let decision = ParkingDecisionEngine.decideFromText("NO STOPPING 7AM-9AM MON-FRI", dateTime: monday(10))
        XCTAssertEqual(decision.canPark, .yes)
    }

    func testNoStoppingAllDay() {
        let decision = ParkingDecisionEngine.decideFromText("NO STOPPING", dateTime: monday(14))
        XCTAssertEqual(decision.canPark, .no)
    }

    func testNoStoppingOnWeekend() {
        let decision = ParkingDecisionEngine.decideFromText("NO STOPPING 7AM-9AM MON-FRI", dateTime: saturday(8))
        XCTAssertEqual(decision.canPark, .yes)
    }

    // MARK: - Clearway

    func testClearwayDuringHours() {
        let decision = ParkingDecisionEngine.decideFromText("CLEARWAY 6AM-10AM MON-FRI", dateTime: monday(7))
        XCTAssertEqual(decision.canPark, .no)
        XCTAssertTrue(decision.warnings.contains { $0.lowercased().contains("tow") })
    }

    func testClearwayOutsideHours() {
        let decision = ParkingDecisionEngine.decideFromText("CLEARWAY 6AM-10AM MON-FRI", dateTime: monday(12))
        XCTAssertEqual(decision.canPark, .yes)
    }

    func testClearwayOnWeekend() {
        let decision = ParkingDecisionEngine.decideFromText("CLEARWAY 6AM-10AM MON-FRI", dateTime: saturday(7))
        XCTAssertEqual(decision.canPark, .yes)
    }

    // MARK: - No Parking

    func testNoParkingDuringHours() {
        let decision = ParkingDecisionEngine.decideFromText("NO PARKING 8AM-6PM MON-FRI", dateTime: monday(10))
        XCTAssertEqual(decision.canPark, .no)
    }

    func testNoParkingOutsideHours() {
        let decision = ParkingDecisionEngine.decideFromText("NO PARKING 8AM-6PM MON-FRI", dateTime: monday(20))
        XCTAssertEqual(decision.canPark, .yes)
    }

    // MARK: - Loading Zone

    func testLoadingZoneDuringHours() {
        let decision = ParkingDecisionEngine.decideFromText("LOADING ZONE 15 MIN 8AM-6PM MON-FRI", dateTime: monday(10))
        XCTAssertEqual(decision.canPark, .no)
        XCTAssertEqual(decision.maxStayMinutes, 15)
    }

    func testLoadingZoneOutsideHours() {
        let decision = ParkingDecisionEngine.decideFromText("LOADING ZONE 15 MIN 8AM-6PM MON-FRI", dateTime: monday(19))
        XCTAssertEqual(decision.canPark, .yes)
    }

    // MARK: - Bus / Taxi / Truck Zones

    func testBusZoneDuringHours() {
        let decision = ParkingDecisionEngine.decideFromText("BUS ZONE 7AM-7PM MON-FRI", dateTime: monday(10))
        XCTAssertEqual(decision.canPark, .no)
    }

    func testTaxiZoneAllDay() {
        let decision = ParkingDecisionEngine.decideFromText("TAXI ZONE", dateTime: monday(14))
        XCTAssertEqual(decision.canPark, .no)
    }

    func testTruckZoneDuringHours() {
        let decision = ParkingDecisionEngine.decideFromText("TRUCK ZONE 6AM-6PM MON-FRI", dateTime: monday(10))
        XCTAssertEqual(decision.canPark, .no)
    }

    // MARK: - Permit Zone

    func testPermitZoneWithoutPermit() {
        let restrictions = SignTextParser.parse(ocrText: "PERMIT ZONE 8AM-6PM MON-FRI")
        let input = ParkingDecisionEngine.Input(
            restrictions: restrictions, dateTime: monday(10),
            calendar: ausCalendar, hasPermit: false
        )
        let decision = ParkingDecisionEngine.decide(input: input)
        XCTAssertEqual(decision.canPark, .no)
    }

    func testPermitZoneWithPermit() {
        let restrictions = SignTextParser.parse(ocrText: "PERMIT ZONE 8AM-6PM MON-FRI")
        let input = ParkingDecisionEngine.Input(
            restrictions: restrictions, dateTime: monday(10),
            calendar: ausCalendar, hasPermit: true
        )
        let decision = ParkingDecisionEngine.decide(input: input)
        XCTAssertEqual(decision.canPark, .yes)
    }

    // MARK: - Public Holidays

    func testTimedParkingOnPublicHolidayExcluded() {
        let decision = ParkingDecisionEngine.decideFromText(
            "2P 8AM-6PM MON-FRI EXCEPT PUBLIC HOLIDAYS",
            dateTime: monday(10), isPublicHoliday: true
        )
        // The time window excludes public holidays, so restriction is not active -> unrestricted
        XCTAssertEqual(decision.canPark, .yes)
        XCTAssertNil(decision.maxStayMinutes)
    }

    func testTimedParkingOnPublicHolidayNotExcluded() {
        let decision = ParkingDecisionEngine.decideFromText(
            "2P 8AM-6PM MON-FRI",
            dateTime: monday(10), isPublicHoliday: true
        )
        // No holiday exclusion specified, so restriction still applies
        XCTAssertEqual(decision.canPark, .yes)
        XCTAssertEqual(decision.maxStayMinutes, 120)
    }

    func testNoStoppingOnPublicHolidayExcluded() {
        let decision = ParkingDecisionEngine.decideFromText(
            "NO STOPPING 7AM-9AM MON-FRI NOT ON PUBLIC HOLIDAYS",
            dateTime: monday(8), isPublicHoliday: true
        )
        XCTAssertEqual(decision.canPark, .yes)
    }

    func testPublicHolidayOnlyRestriction() {
        let decision = ParkingDecisionEngine.decideFromText(
            "NO PARKING 8AM-6PM PUBLIC HOLIDAYS ONLY",
            dateTime: monday(10), isPublicHoliday: true
        )
        XCTAssertEqual(decision.canPark, .no)
    }

    func testPublicHolidayOnlyRestrictionOnNormalDay() {
        let decision = ParkingDecisionEngine.decideFromText(
            "NO PARKING 8AM-6PM PUBLIC HOLIDAYS ONLY",
            dateTime: monday(10), isPublicHoliday: false
        )
        XCTAssertEqual(decision.canPark, .yes)
    }

    // MARK: - School Days

    func testSchoolDayRestrictionOnSchoolDay() {
        let decision = ParkingDecisionEngine.decideFromText(
            "NO STOPPING 8AM-9AM SCHOOL DAYS",
            dateTime: monday(8, 30), isSchoolDay: true
        )
        XCTAssertEqual(decision.canPark, .no)
    }

    func testSchoolDayRestrictionOnNonSchoolDay() {
        let decision = ParkingDecisionEngine.decideFromText(
            "NO STOPPING 8AM-9AM SCHOOL DAYS",
            dateTime: monday(8, 30), isSchoolDay: false
        )
        // School day restriction does not apply on non-school day
        XCTAssertEqual(decision.canPark, .yes)
    }

    // MARK: - Payment Status

    func testPaymentRequiredMeter() {
        let decision = ParkingDecisionEngine.decideFromText("2P METER 8AM-6PM MON-FRI", dateTime: monday(10))
        XCTAssertEqual(decision.canPark, .yes)
        XCTAssertEqual(decision.paymentStatus, .paid)
        XCTAssertTrue(decision.warnings.contains { $0.lowercased().contains("meter") })
    }

    func testPaymentRequiredTicket() {
        let decision = ParkingDecisionEngine.decideFromText("2P TICKET 8AM-6PM MON-FRI", dateTime: monday(10))
        XCTAssertEqual(decision.paymentStatus, .paid)
        XCTAssertTrue(decision.warnings.contains { $0.lowercased().contains("ticket") })
    }

    func testFreeParking() {
        let decision = ParkingDecisionEngine.decideFromText("2P 8AM-6PM MON-FRI", dateTime: monday(10))
        XCTAssertEqual(decision.paymentStatus, .free)
    }

    func testFreeOutsideHours() {
        let decision = ParkingDecisionEngine.decideFromText("2P METER 8AM-6PM MON-FRI", dateTime: monday(19))
        XCTAssertEqual(decision.paymentStatus, .free)
    }

    // MARK: - Near End of Window

    func testNearEndOfWindowWarning() {
        // At 5:50 PM with window ending at 6 PM -> 10 minutes remaining -> warning
        let decision = ParkingDecisionEngine.decideFromText("2P 8AM-6PM MON-FRI", dateTime: monday(17, 50))
        XCTAssertEqual(decision.canPark, .yes)
        XCTAssertTrue(decision.warnings.contains { $0.contains("minutes") })
    }

    func testExactlyAtWindowEnd() {
        // At 6:00 PM with window ending at 6 PM
        let decision = ParkingDecisionEngine.decideFromText("2P 8AM-6PM MON-FRI", dateTime: monday(18))
        // At the exact end time the window still contains it (<=), so restriction is active
        XCTAssertEqual(decision.canPark, .yes)
    }

    // MARK: - Explanation and Next Change

    func testExplanationContainsUsefulInfo() {
        let decision = ParkingDecisionEngine.decideFromText("2P METER 8AM-6PM MON-FRI", dateTime: monday(10))
        XCTAssertFalse(decision.explanation.isEmpty)
        XCTAssertTrue(decision.explanation.lowercased().contains("park"))
    }

    func testNextChangeNotEmpty() {
        let decision = ParkingDecisionEngine.decideFromText("2P 8AM-6PM MON-FRI", dateTime: monday(10))
        XCTAssertFalse(decision.nextChange.isEmpty)
    }

    // MARK: - Confidence

    func testHighConfidenceForClearSign() {
        let decision = ParkingDecisionEngine.decideFromText("NO STOPPING 7AM-9AM MON-FRI", dateTime: monday(8))
        XCTAssertGreaterThanOrEqual(decision.confidence, 0.7)
    }

    func testLowerConfidenceForAmbiguousText() {
        let decision = ParkingDecisionEngine.decideFromText("P", dateTime: monday(10))
        // A lone "P" is quite ambiguous
        XCTAssertLessThan(decision.confidence, 0.8)
    }

    // MARK: - Empty / Unknown Input

    func testEmptyTextReturnsUncertain() {
        let restrictions = SignTextParser.parse(ocrText: "")
        let input = ParkingDecisionEngine.Input(restrictions: restrictions, dateTime: monday(10), calendar: ausCalendar)
        let decision = ParkingDecisionEngine.decide(input: input)
        // No restrictions means unrestricted
        XCTAssertEqual(decision.canPark, .yes)
    }

    func testGarbageTextReturnsUnrestricted() {
        let decision = ParkingDecisionEngine.decideFromText("xyzzy gibberish", dateTime: monday(10))
        // Parser returns empty restrictions -> engine treats as unrestricted
        XCTAssertEqual(decision.canPark, .yes)
    }

    // MARK: - Vehicle Type Exemptions

    func testBusExemptFromNoStopping() {
        let restrictions = SignTextParser.parse(ocrText: "NO STOPPING EXCEPT BUSES 7AM-9AM MON-FRI")
        let input = ParkingDecisionEngine.Input(
            restrictions: restrictions, dateTime: monday(8),
            calendar: ausCalendar, vehicleType: .bus
        )
        let decision = ParkingDecisionEngine.decide(input: input)
        XCTAssertEqual(decision.canPark, .yes)
    }

    func testCarNotExemptFromNoStoppingExceptBuses() {
        let restrictions = SignTextParser.parse(ocrText: "NO STOPPING EXCEPT BUSES 7AM-9AM MON-FRI")
        let input = ParkingDecisionEngine.Input(
            restrictions: restrictions, dateTime: monday(8),
            calendar: ausCalendar, vehicleType: .car
        )
        let decision = ParkingDecisionEngine.decide(input: input)
        XCTAssertEqual(decision.canPark, .no)
    }

    func testTaxiExemptFromNoStoppingExceptTaxis() {
        let restrictions = SignTextParser.parse(ocrText: "NO STOPPING EXCEPT TAXIS 7AM-9AM MON-FRI")
        let input = ParkingDecisionEngine.Input(
            restrictions: restrictions, dateTime: monday(8),
            calendar: ausCalendar, vehicleType: .taxi
        )
        let decision = ParkingDecisionEngine.decide(input: input)
        XCTAssertEqual(decision.canPark, .yes)
    }

    // MARK: - Active Restriction Tracking

    func testActiveRestrictionReturnedWhenActive() {
        let decision = ParkingDecisionEngine.decideFromText("NO STOPPING 7AM-9AM MON-FRI", dateTime: monday(8))
        XCTAssertNotNil(decision.activeRestriction)
        XCTAssertEqual(decision.activeRestriction?.category, .noStopping)
    }

    func testNoActiveRestrictionWhenOutsideHours() {
        let decision = ParkingDecisionEngine.decideFromText("NO STOPPING 7AM-9AM MON-FRI", dateTime: monday(12))
        XCTAssertNil(decision.activeRestriction)
    }
}
