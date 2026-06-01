// ExplanationGenerator.swift
// CanIPark

import Foundation

struct ExplanationGenerator {

    static func generateExplanation(
        canPark: ParkingAbility, category: SignCategory, maxStayMinutes: Int?,
        paymentStatus: PaymentStatus, legalUntil: Date?, activeWindow: TimeWindow?,
        calendar: Calendar, dateTime: Date
    ) -> String {
        var parts: [String] = []

        switch canPark {
        case .yes:
            parts.append("You can park here now.")
        case .no:
            parts.append("You cannot park here now.")
        case .uncertain:
            parts.append("It is unclear whether you can park here.")
        }

        switch category {
        case .noStopping:
            parts.append("No stopping is in effect — you cannot stop your vehicle here at all.")
        case .clearway:
            parts.append("A clearway is active. Your vehicle may be towed.")
        case .noParking:
            parts.append("No parking is in effect. You may stop briefly (up to 2 minutes) for passenger pickup only.")
        case .busZone:
            parts.append("This is a bus zone. Only buses may stop here.")
        case .taxiZone:
            parts.append("This is a taxi zone. Only taxis may stop here.")
        case .truckZone:
            parts.append("This is a truck zone. Only trucks may stop here.")
        case .loadingZone:
            parts.append("This is a loading zone. Only loading and unloading is permitted.")
            if let minutes = maxStayMinutes { parts.append("Maximum loading time: \(minutes) minutes.") }
        case .permitZone:
            parts.append("This is a permit zone.")
        case .timedParking:
            if let minutes = maxStayMinutes {
                let display = minutes >= 60 ? "\(minutes / 60) hour\(minutes / 60 == 1 ? "" : "s")" : "\(minutes) minutes"
                parts.append("Maximum stay: \(display).")
            }
        default: break
        }

        if let until = legalUntil, canPark == .yes {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            formatter.calendar = calendar
            parts.append("Until \(formatter.string(from: until)).")
        }

        switch paymentStatus {
        case .paid: parts.append("Payment is required.")
        case .free: if canPark == .yes { parts.append("Parking is free.") }
        case .unknown: break
        }

        if let window = activeWindow {
            let dayRange = describeDays(window.daysOfWeek)
            let timeRange = "\(window.startTime.formatted) – \(window.endTime.formatted)"
            parts.append("Based on: \(dayRange) \(timeRange).")
        }

        return parts.joined(separator: " ")
    }

    static func generateHeadline(from decision: ParkingDecision) -> String {
        switch decision.canPark {
        case .yes:
            if let until = decision.legalUntil {
                let formatter = DateFormatter()
                formatter.dateFormat = "h:mm a"
                return "You can park here until \(formatter.string(from: until))"
            }
            return "You can park here now"
        case .no:
            return "You cannot park here now"
        case .uncertain:
            return "Not enough information"
        }
    }

    private static func describeDays(_ days: Set<DayOfWeek>) -> String {
        if days == DayOfWeek.allDays { return "Every day" }
        if days == DayOfWeek.weekdays { return "Mon–Fri" }
        if days == DayOfWeek.weekend { return "Sat–Sun" }

        let sorted = days.sorted()
        if sorted.count == 1 { return sorted[0].fullName }

        let consecutive = isConsecutive(sorted)
        if consecutive && sorted.count > 2 {
            return "\(sorted.first!.abbreviation)–\(sorted.last!.abbreviation)"
        }

        return sorted.map(\.abbreviation).joined(separator: ", ")
    }

    private static func isConsecutive(_ sorted: [DayOfWeek]) -> Bool {
        let ordered: [DayOfWeek] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
        guard let startIdx = ordered.firstIndex(of: sorted[0]) else { return false }
        for (i, day) in sorted.enumerated() {
            let expected = ordered[(startIdx + i) % ordered.count]
            if day != expected { return false }
        }
        return true
    }
}
