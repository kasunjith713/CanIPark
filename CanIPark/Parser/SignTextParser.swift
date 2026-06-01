// SignTextParser.swift
// CanIPark
//
// Parses OCR text from Australian parking signs into structured
// ParkingRestriction objects using regex-based tokenisation.

import Foundation

struct SignTextParser {

    // MARK: - Public API

    static func parse(ocrText: String) -> [ParkingRestriction] {
        let cleaned = preprocessText(ocrText)
        let panels = splitIntoPanels(cleaned)

        var restrictions: [ParkingRestriction] = []
        for panel in panels {
            if let restriction = parsePanel(panel) {
                restrictions.append(restriction)
            }
        }

        if restrictions.isEmpty {
            if let restriction = parsePanel(cleaned) {
                restrictions.append(restriction)
            }
        }

        return restrictions
    }

    static func parsePanel(_ text: String) -> ParkingRestriction? {
        let upper = text.uppercased()
        let (category, maxStayMinutes, categoryConfidence) = detectCategory(upper)

        if category == .unknown { return nil }

        let timeWindows = TimeWindowParser.parse(from: text)
        let paymentType = detectPaymentType(upper)
        let exemptions = detectExemptions(upper)
        let arrowDirection = detectArrowDirection(upper)
        let confidence = computeConfidence(
            categoryConfidence: categoryConfidence,
            hasTimeWindows: !timeWindows.isEmpty,
            text: upper
        )

        return ParkingRestriction(
            category: category,
            maxStayMinutes: maxStayMinutes,
            timeWindows: timeWindows,
            paymentType: paymentType,
            exemptions: exemptions,
            arrowDirection: arrowDirection,
            rawText: text.trimmingCharacters(in: .whitespacesAndNewlines),
            confidence: confidence
        )
    }

    // MARK: - Text Preprocessing

    private static func preprocessText(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")
        result = result.replacingOccurrences(of: "\u{2013}", with: "-")
        result = result.replacingOccurrences(of: "\u{2014}", with: "-")

        let ocrFixes: [(pattern: String, replacement: String)] = [
            (#"(?i)\bN0\b"#, "NO"),
            (#"(?i)\bST0PPING\b"#, "STOPPING"),
            (#"(?i)\bPARKlNG\b"#, "PARKING"),
            (#"(?i)\bZ0NE\b"#, "ZONE"),
            (#"(?i)\bL0ADING\b"#, "LOADING"),
        ]
        for fix in ocrFixes {
            if let regex = try? NSRegularExpression(pattern: fix.pattern) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(location: 0, length: result.utf16.count),
                    withTemplate: fix.replacement
                )
            }
        }
        return result
    }

    private static func splitIntoPanels(_ text: String) -> [String] {
        let separatorPattern = #"\n\s*\n|\n[-=]{3,}\n"#
        guard let regex = try? NSRegularExpression(pattern: separatorPattern) else {
            return [text]
        }

        let nsText = text as NSString
        var panels: [String] = []
        var lastEnd = 0

        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        for match in matches {
            let panelRange = NSRange(location: lastEnd, length: match.range.location - lastEnd)
            let panel = nsText.substring(with: panelRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if !panel.isEmpty { panels.append(panel) }
            lastEnd = match.range.location + match.range.length
        }

        let remaining = nsText.substring(from: lastEnd).trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty { panels.append(remaining) }

        return panels.isEmpty ? [text] : panels
    }

    // MARK: - Category Detection

    private static func detectCategory(_ text: String) -> (SignCategory, Int?, Double) {
        if matchesPattern(text, #"\bNO\s+STOPPING\b"#) { return (.noStopping, nil, 0.95) }
        if matchesPattern(text, #"\bCLEARWAY\b"#) { return (.clearway, nil, 0.95) }
        if matchesPattern(text, #"\bNO\s+PARKING\b"#) { return (.noParking, nil, 0.95) }
        if matchesPattern(text, #"\bBUS\s+ZONE\b"#) { return (.busZone, nil, 0.93) }
        if matchesPattern(text, #"\bTAXI\s+ZONE\b"#) { return (.taxiZone, nil, 0.93) }
        if matchesPattern(text, #"\bTRUCK\s+ZONE\b"#) { return (.truckZone, nil, 0.93) }
        if matchesPattern(text, #"\bWORKS?\s+ZONE\b"#) { return (.worksZone, nil, 0.93) }
        if matchesPattern(text, #"\bMAIL\s+ZONE\b"#) { return (.mailZone, nil, 0.93) }

        if matchesPattern(text, #"\bLOADING\s+ZONE\b"#) {
            let minutes = parseTimedDuration(text)
            return (.loadingZone, minutes, 0.93)
        }

        if matchesPattern(text, #"\bPERMIT\s+ZONE\b"#) || matchesPattern(text, #"\bPERMIT\s+HOLDERS?\s+ONLY\b"#) {
            return (.permitZone, nil, 0.90)
        }

        if matchesPattern(text, #"\bDISABILITY\b"#) || matchesPattern(text, #"\bACCESSIBLE\b"#) || matchesPattern(text, #"\bACROD\b"#) {
            let minutes = parseTimedDuration(text)
            return (.accessible, minutes, 0.90)
        }

        if matchesPattern(text, #"\bEV\s+CHARGING\b"#) || matchesPattern(text, #"\bELECTRIC\s+VEHICLE\b"#) {
            let minutes = parseTimedDuration(text)
            return (.evCharging, minutes, 0.90)
        }

        if let minutes = parseTimedDuration(text) {
            return (.timedParking, minutes, 0.90)
        }

        if matchesPattern(text, #"\bP\b"#) && !matchesPattern(text, #"\d\s*P\b"#) {
            return (.timedParking, nil, 0.70)
        }

        return (.unknown, nil, 0.0)
    }

    private static func parseTimedDuration(_ text: String) -> Int? {
        if matchesPattern(text, #"\b1\s*/\s*2\s*P\b"#) { return 30 }
        if matchesPattern(text, #"\b1\s*/\s*4\s*P\b"#) { return 15 }

        let npPattern = #"\b(\d{1,2})\s*P\b"#
        if let match = firstMatch(text, npPattern), let hours = Int(match[1]) {
            return hours * 60
        }

        let minPattern = #"\b(\d{1,3})\s*(?:MIN(?:UTE)?S?)\b"#
        if let match = firstMatch(text, minPattern), let mins = Int(match[1]) {
            return mins
        }

        let hourPattern = #"\b(\d{1,2})\s*(?:HOUR|HR)S?\b"#
        if let match = firstMatch(text, hourPattern), let hours = Int(match[1]) {
            return hours * 60
        }

        return nil
    }

    // MARK: - Payment Detection

    private static func detectPaymentType(_ text: String) -> PaymentType {
        if matchesPattern(text, #"\bMETER\b"#) { return .meter }
        if matchesPattern(text, #"\bTICKET\b"#) { return .ticket }
        if matchesPattern(text, #"\bPAY\s+HERE\b"#) || matchesPattern(text, #"\bPAY\s+&?\s*DISPLAY\b"#) { return .payHere }
        if matchesPattern(text, #"\bPAY\s+BY\s+APP\b"#) || matchesPattern(text, #"\bAPP\s+PARKING\b"#) { return .app }
        return .none
    }

    // MARK: - Exemption Detection

    private static func detectExemptions(_ text: String) -> [Exemption] {
        var exemptions: [Exemption] = []
        if matchesPattern(text, #"\bEXCEPT\s+BUSES\b"#) || matchesPattern(text, #"\bBUS(?:ES)?\s+EXCEPTED\b"#) { exemptions.append(.buses) }
        if matchesPattern(text, #"\bEXCEPT\s+TAXIS?\b"#) || matchesPattern(text, #"\bTAXI(?:S)?\s+EXCEPTED\b"#) { exemptions.append(.taxis) }
        if matchesPattern(text, #"\bEXCEPT\s+TRUCKS?\b"#) || matchesPattern(text, #"\bTRUCK(?:S)?\s+EXCEPTED\b"#) { exemptions.append(.trucks) }
        if matchesPattern(text, #"\bPERMIT\s+HOLDERS?\s+EXCEPTED\b"#) || matchesPattern(text, #"\bEXCEPT\s+PERMIT\s+HOLDERS?\b"#) || matchesPattern(text, #"\bWITH\s+PERMIT\b"#) { exemptions.append(.permitHolders) }
        if matchesPattern(text, #"\bDISABILITY\b"#) || matchesPattern(text, #"\bDISABLED\b"#) || matchesPattern(text, #"\bACROD\b"#) || matchesPattern(text, #"\bMOBILITY\b"#) { exemptions.append(.disabilityPermit) }
        if matchesPattern(text, #"\bEMERGENCY\b"#) { exemptions.append(.emergencyVehicles) }
        if matchesPattern(text, #"\bMOTORCYCLE\b"#) || matchesPattern(text, #"\bMOTOR\s+CYCLE\b"#) { exemptions.append(.motorcycles) }
        if matchesPattern(text, #"\bBICYCLE\b"#) || matchesPattern(text, #"\bBIKE\b"#) { exemptions.append(.bicycles) }
        return exemptions
    }

    // MARK: - Arrow Direction Detection

    private static func detectArrowDirection(_ text: String) -> ArrowDirection {
        let hasLeft = matchesPattern(text, #"<[-–—]|←|\bLEFT\b"#)
        let hasRight = matchesPattern(text, #"[-–—]>|→|\bRIGHT\b"#)
        if hasLeft && hasRight { return .both }
        if hasLeft { return .left }
        if hasRight { return .right }
        return .none
    }

    // MARK: - Confidence

    private static func computeConfidence(categoryConfidence: Double, hasTimeWindows: Bool, text: String) -> Double {
        var confidence = categoryConfidence
        if hasTimeWindows { confidence = min(1.0, confidence + 0.03) }
        if text.count < 5 { confidence *= 0.7 }
        let alphaCount = text.filter { $0.isLetter || $0.isNumber }.count
        let ratio = Double(alphaCount) / max(1.0, Double(text.count))
        if ratio < 0.5 { confidence *= 0.8 }
        return min(1.0, max(0.0, confidence))
    }

    // MARK: - Regex Helpers

    private static func matchesPattern(_ text: String, _ pattern: String) -> Bool {
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func firstMatch(_ text: String, _ pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)) else { return nil }
        var groups: [String] = []
        for i in 0..<match.numberOfRanges {
            if match.range(at: i).location != NSNotFound {
                groups.append(nsText.substring(with: match.range(at: i)))
            } else {
                groups.append("")
            }
        }
        return groups
    }
}
