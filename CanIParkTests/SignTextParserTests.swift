// SignTextParserTests.swift
// CanIParkTests

import XCTest
@testable import CanIPark

final class SignTextParserTests: XCTestCase {

    // MARK: - Helper

    private func parseSingle(_ text: String) -> ParkingRestriction? {
        let results = SignTextParser.parse(ocrText: text)
        return results.first
    }

    // MARK: - Timed Parking (nP format)

    func testParse2P() {
        let r = parseSingle("2P")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .timedParking)
        XCTAssertEqual(r?.maxStayMinutes, 120)
    }

    func testParse1P() {
        let r = parseSingle("1P")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .timedParking)
        XCTAssertEqual(r?.maxStayMinutes, 60)
    }

    func testParse4P() {
        let r = parseSingle("4P")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .timedParking)
        XCTAssertEqual(r?.maxStayMinutes, 240)
    }

    func testParse10P() {
        let r = parseSingle("10P")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .timedParking)
        XCTAssertEqual(r?.maxStayMinutes, 600)
    }

    func testParseHalfP() {
        let r = parseSingle("1/2P")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .timedParking)
        XCTAssertEqual(r?.maxStayMinutes, 30)
    }

    func testParseQuarterP() {
        let r = parseSingle("1/4P")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .timedParking)
        XCTAssertEqual(r?.maxStayMinutes, 15)
    }

    // MARK: - Timed Parking (minute format)

    func testParse15Min() {
        let r = parseSingle("15 MIN")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .timedParking)
        XCTAssertEqual(r?.maxStayMinutes, 15)
    }

    func testParse30Minutes() {
        let r = parseSingle("30 MINUTES")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .timedParking)
        XCTAssertEqual(r?.maxStayMinutes, 30)
    }

    func testParse5Mins() {
        let r = parseSingle("5 MINS")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .timedParking)
        XCTAssertEqual(r?.maxStayMinutes, 5)
    }

    // MARK: - Timed Parking (hour format)

    func testParse2Hours() {
        let r = parseSingle("2 HOURS")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .timedParking)
        XCTAssertEqual(r?.maxStayMinutes, 120)
    }

    func testParse1Hour() {
        let r = parseSingle("1 HOUR")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .timedParking)
        XCTAssertEqual(r?.maxStayMinutes, 60)
    }

    func testParse3Hrs() {
        let r = parseSingle("3 HRS")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .timedParking)
        XCTAssertEqual(r?.maxStayMinutes, 180)
    }

    // MARK: - No Stopping

    func testParseNoStopping() {
        let r = parseSingle("NO STOPPING")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .noStopping)
        XCTAssertNil(r?.maxStayMinutes)
    }

    func testParseNoStoppingWithTime() {
        let r = parseSingle("NO STOPPING 7AM-9AM MON-FRI")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .noStopping)
        XCTAssertFalse(r?.timeWindows.isEmpty ?? true)
    }

    // MARK: - No Parking

    func testParseNoParking() {
        let r = parseSingle("NO PARKING")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .noParking)
        XCTAssertNil(r?.maxStayMinutes)
    }

    func testParseNoParkingWithTimeRange() {
        let r = parseSingle("NO PARKING 6AM-6PM")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .noParking)
    }

    // MARK: - Clearway

    func testParseClearway() {
        let r = parseSingle("CLEARWAY")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .clearway)
    }

    func testParseClearwayWithTime() {
        let r = parseSingle("CLEARWAY 6AM-10AM MON-FRI")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .clearway)
        XCTAssertFalse(r?.timeWindows.isEmpty ?? true)
    }

    // MARK: - Loading Zone

    func testParseLoadingZone() {
        let r = parseSingle("LOADING ZONE")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .loadingZone)
    }

    func testParseLoadingZone15Min() {
        let r = parseSingle("LOADING ZONE 15 MIN")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .loadingZone)
        XCTAssertEqual(r?.maxStayMinutes, 15)
    }

    func testParseLoadingZone30Minutes() {
        let r = parseSingle("LOADING ZONE 30 MINUTES")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .loadingZone)
        XCTAssertEqual(r?.maxStayMinutes, 30)
    }

    // MARK: - Special Zones

    func testParseBusZone() {
        let r = parseSingle("BUS ZONE")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .busZone)
    }

    func testParseTaxiZone() {
        let r = parseSingle("TAXI ZONE")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .taxiZone)
    }

    func testParseTruckZone() {
        let r = parseSingle("TRUCK ZONE")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .truckZone)
    }

    func testParseWorksZone() {
        let r = parseSingle("WORKS ZONE")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .worksZone)
    }

    func testParseMailZone() {
        let r = parseSingle("MAIL ZONE")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .mailZone)
    }

    // MARK: - Permit Zone

    func testParsePermitZone() {
        let r = parseSingle("PERMIT ZONE")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .permitZone)
    }

    func testParsePermitHoldersOnly() {
        let r = parseSingle("PERMIT HOLDERS ONLY")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .permitZone)
    }

    // MARK: - Accessible Parking

    func testParseDisabilityParking() {
        let r = parseSingle("DISABILITY 2P")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .accessible)
        XCTAssertEqual(r?.maxStayMinutes, 120)
    }

    func testParseAccessibleParking() {
        let r = parseSingle("ACCESSIBLE 1P")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .accessible)
        XCTAssertEqual(r?.maxStayMinutes, 60)
    }

    func testParseAcrodParking() {
        let r = parseSingle("ACROD 2P")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .accessible)
    }

    // MARK: - EV Charging

    func testParseEVCharging() {
        let r = parseSingle("EV CHARGING 2P")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .evCharging)
        XCTAssertEqual(r?.maxStayMinutes, 120)
    }

    func testParseElectricVehicle() {
        let r = parseSingle("ELECTRIC VEHICLE 1P")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .evCharging)
        XCTAssertEqual(r?.maxStayMinutes, 60)
    }

    // MARK: - Payment Types

    func testParsePaymentMeter() {
        let r = parseSingle("2P METER")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.paymentType, .meter)
    }

    func testParsePaymentTicket() {
        let r = parseSingle("2P TICKET")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.paymentType, .ticket)
    }

    func testParsePaymentPayHere() {
        let r = parseSingle("2P PAY HERE")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.paymentType, .payHere)
    }

    func testParsePayAndDisplay() {
        let r = parseSingle("2P PAY & DISPLAY")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.paymentType, .payHere)
    }

    func testParsePayByApp() {
        let r = parseSingle("2P PAY BY APP")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.paymentType, .app)
    }

    func testParseAppParking() {
        let r = parseSingle("1P APP PARKING")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.paymentType, .app)
    }

    func testParseNoPaymentIndicator() {
        let r = parseSingle("2P")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.paymentType, .none)
    }

    // MARK: - Exemptions

    func testParseExceptBuses() {
        let r = parseSingle("NO STOPPING EXCEPT BUSES")
        XCTAssertNotNil(r)
        XCTAssertTrue(r?.exemptions.contains(.buses) ?? false)
    }

    func testParseBusesExcepted() {
        let r = parseSingle("NO STOPPING BUSES EXCEPTED")
        XCTAssertNotNil(r)
        XCTAssertTrue(r?.exemptions.contains(.buses) ?? false)
    }

    func testParseExceptTaxis() {
        let r = parseSingle("NO STOPPING EXCEPT TAXIS")
        XCTAssertNotNil(r)
        XCTAssertTrue(r?.exemptions.contains(.taxis) ?? false)
    }

    func testParsePermitHoldersExcepted() {
        let r = parseSingle("NO PARKING PERMIT HOLDERS EXCEPTED")
        XCTAssertNotNil(r)
        XCTAssertTrue(r?.exemptions.contains(.permitHolders) ?? false)
    }

    func testParseWithPermit() {
        let r = parseSingle("2P WITH PERMIT")
        XCTAssertNotNil(r)
        XCTAssertTrue(r?.exemptions.contains(.permitHolders) ?? false)
    }

    func testParseExceptTrucks() {
        let r = parseSingle("NO STOPPING EXCEPT TRUCKS")
        XCTAssertNotNil(r)
        XCTAssertTrue(r?.exemptions.contains(.trucks) ?? false)
    }

    func testParseEmergencyExemption() {
        let r = parseSingle("NO STOPPING EMERGENCY")
        XCTAssertNotNil(r)
        XCTAssertTrue(r?.exemptions.contains(.emergencyVehicles) ?? false)
    }

    func testParseMotorcycleExemption() {
        let r = parseSingle("2P MOTORCYCLE")
        XCTAssertNotNil(r)
        XCTAssertTrue(r?.exemptions.contains(.motorcycles) ?? false)
    }

    // MARK: - Arrow Direction

    func testParseLeftArrow() {
        let r = parseSingle("2P <--")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.arrowDirection, .left)
    }

    func testParseRightArrow() {
        let r = parseSingle("2P -->")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.arrowDirection, .right)
    }

    func testParseBothArrows() {
        let r = parseSingle("2P <-->")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.arrowDirection, .both)
    }

    func testParseNoArrow() {
        let r = parseSingle("2P")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.arrowDirection, .none)
    }

    // MARK: - OCR Error Correction

    func testParseOCRZeroForO() {
        let r = parseSingle("N0 ST0PPING")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .noStopping)
    }

    func testParseOCRlForI() {
        let r = parseSingle("PARKlNG 2P")
        XCTAssertNotNil(r)
        // Should still parse the 2P after OCR correction
        XCTAssertEqual(r?.maxStayMinutes, 120)
    }

    func testParseOCRLoadingZoneCorrection() {
        let r = parseSingle("L0ADING Z0NE")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .loadingZone)
    }

    // MARK: - Multi-Panel Parsing

    func testParseMultiplePanels() {
        let text = "2P METER 8AM-6PM MON-FRI\n\n1P 8AM-12PM SAT"
        let results = SignTextParser.parse(ocrText: text)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].maxStayMinutes, 120)
        XCTAssertEqual(results[1].maxStayMinutes, 60)
    }

    func testParseSinglePanelNoSplit() {
        let text = "2P 8AM-6PM MON-FRI"
        let results = SignTextParser.parse(ocrText: text)
        XCTAssertEqual(results.count, 1)
    }

    // MARK: - Confidence

    func testConfidenceHighForClearSign() {
        let r = parseSingle("NO STOPPING 7AM-9AM MON-FRI")
        XCTAssertNotNil(r)
        XCTAssertGreaterThan(r!.confidence, 0.8)
    }

    func testConfidenceLowerForVeryShortText() {
        let r = parseSingle("2P")
        XCTAssertNotNil(r)
        // Short text reduces confidence
        XCTAssertLessThanOrEqual(r!.confidence, 0.95)
    }

    // MARK: - Edge Cases

    func testParseEmptyText() {
        let results = SignTextParser.parse(ocrText: "")
        XCTAssertTrue(results.isEmpty)
    }

    func testParseGarbageText() {
        let results = SignTextParser.parse(ocrText: "asdf jkl;")
        XCTAssertTrue(results.isEmpty)
    }

    func testParseOnlyWhitespace() {
        let results = SignTextParser.parse(ocrText: "   \n\n  ")
        XCTAssertTrue(results.isEmpty)
    }

    func testParseRawTextPreserved() {
        let r = parseSingle("2P METER 8AM-6PM")
        XCTAssertNotNil(r)
        XCTAssertTrue(r!.rawText.contains("2P"))
    }

    // MARK: - Combined Sign Features

    func testParseTimedParkingWithDaysAndPayment() {
        let r = parseSingle("2P METER 8AM-6PM MON-FRI")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .timedParking)
        XCTAssertEqual(r?.maxStayMinutes, 120)
        XCTAssertEqual(r?.paymentType, .meter)
        XCTAssertFalse(r?.timeWindows.isEmpty ?? true)
    }

    func testParseClearwayWithFullDetails() {
        let r = parseSingle("CLEARWAY 6AM-10AM MON-FRI")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .clearway)
        XCTAssertFalse(r?.timeWindows.isEmpty ?? true)
    }

    func testParseNoStoppingWithExemptionAndTime() {
        let r = parseSingle("NO STOPPING EXCEPT BUSES 7AM-9AM MON-FRI")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .noStopping)
        XCTAssertTrue(r?.exemptions.contains(.buses) ?? false)
        XCTAssertFalse(r?.timeWindows.isEmpty ?? true)
    }

    // MARK: - Unicode and Special Characters

    func testParseEnDashTimeRange() {
        let r = parseSingle("2P 8AM\u{2013}6PM")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .timedParking)
    }

    func testParseEmDashTimeRange() {
        let r = parseSingle("2P 8AM\u{2014}6PM")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .timedParking)
    }

    func testParseCarriageReturn() {
        let r = parseSingle("2P\r\n8AM-6PM")
        XCTAssertNotNil(r)
        XCTAssertEqual(r?.category, .timedParking)
    }
}
