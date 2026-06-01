// ParkingDecisionEngine.swift
// CanIPark

import Foundation

struct ParkingDecisionEngine {

    struct Input {
        let restrictions: [ParkingRestriction]
        let dateTime: Date
        let calendar: Calendar
        let isSchoolDay: Bool
        let isPublicHoliday: Bool
        let hasPermit: Bool
        let vehicleType: VehicleType

        init(restrictions: [ParkingRestriction], dateTime: Date = Date(), calendar: Calendar = .current,
             isSchoolDay: Bool = false, isPublicHoliday: Bool = false, hasPermit: Bool = false,
             vehicleType: VehicleType = .car) {
            self.restrictions = restrictions; self.dateTime = dateTime; self.calendar = calendar
            self.isSchoolDay = isSchoolDay; self.isPublicHoliday = isPublicHoliday
            self.hasPermit = hasPermit; self.vehicleType = vehicleType
        }
    }

    enum VehicleType: String, Codable {
        case car, bus, taxi, truck, motorcycle, bicycle, emergency
    }

    static func decide(input: Input) -> ParkingDecision {
        let context = RestrictionResolver.Context(dateTime: input.dateTime, calendar: input.calendar,
                                                   isSchoolDay: input.isSchoolDay, isPublicHoliday: input.isPublicHoliday)
        let resolution = RestrictionResolver.resolve(restrictions: input.restrictions, context: context)

        if resolution.isUnrestricted {
            return makeUnrestrictedDecision(input: input, resolution: resolution, context: context)
        }

        guard let active = resolution.activeRestriction else {
            return makeUnrestrictedDecision(input: input, resolution: resolution, context: context)
        }

        if isExempt(vehicleType: input.vehicleType, exemptions: active.exemptions) {
            return makeExemptDecision(input: input, active: active, resolution: resolution, context: context)
        }

        if input.hasPermit && active.exemptions.contains(.permitHolders) {
            return makePermitExemptDecision(input: input, active: active, resolution: resolution, context: context)
        }

        switch active.category {
        case .noStopping: return makeProhibitiveDecision(input: input, active: active, resolution: resolution, context: context, kind: "No stopping", warning: "No stopping means you cannot stop your vehicle here at all, even briefly.", tow: false)
        case .clearway: return makeProhibitiveDecision(input: input, active: active, resolution: resolution, context: context, kind: "Clearway", warning: "Clearway in effect. Your vehicle may be towed.", tow: true)
        case .noParking: return makeProhibitiveDecision(input: input, active: active, resolution: resolution, context: context, kind: "No parking", warning: "No parking means you may stop briefly (up to 2 minutes) to pick up or drop off passengers, but you must remain with your vehicle.", tow: false)
        case .busZone, .taxiZone, .truckZone, .worksZone, .mailZone:
            return makeZoneDecision(input: input, active: active, resolution: resolution, context: context)
        case .loadingZone: return makeLoadingZoneDecision(input: input, active: active, resolution: resolution, context: context)
        case .permitZone: return makePermitZoneDecision(input: input, active: active, resolution: resolution, context: context)
        case .timedParking, .accessible, .evCharging: return makeTimedParkingDecision(input: input, active: active, resolution: resolution, context: context)
        case .unrestricted: return makeUnrestrictedDecision(input: input, resolution: resolution, context: context)
        case .unknown: return makeUncertainDecision(resolution: resolution)
        }
    }

    static func decideFromText(_ ocrText: String, dateTime: Date = Date(), isSchoolDay: Bool = false, isPublicHoliday: Bool = false) -> ParkingDecision {
        let restrictions = SignTextParser.parse(ocrText: ocrText)
        return decide(input: Input(restrictions: restrictions, dateTime: dateTime, isSchoolDay: isSchoolDay, isPublicHoliday: isPublicHoliday))
    }

    // MARK: - Decision Builders

    private static func makeUnrestrictedDecision(input: Input, resolution: RestrictionResolver.ResolutionResult, context: RestrictionResolver.Context) -> ParkingDecision {
        let nextChange = RestrictionResolver.nextChangeTime(for: input.restrictions, context: context)
        var warnings: [String] = []
        if !input.restrictions.isEmpty { warnings.append("Restrictions apply at other times. Check sign times carefully.") }
        let explanation = "No parking restrictions are currently active. You can park here freely."
        return ParkingDecision(canPark: .yes, legalUntil: nextChange, maxStayMinutes: nil, paymentStatus: .free,
                              explanation: explanation, nextChange: describeNextChange(nextChange, calendar: input.calendar, dateTime: input.dateTime),
                              confidence: resolution.confidence, warnings: warnings, activeRestriction: nil)
    }

    private static func makeProhibitiveDecision(input: Input, active: ParkingRestriction, resolution: RestrictionResolver.ResolutionResult, context: RestrictionResolver.Context, kind: String, warning: String, tow: Bool) -> ParkingDecision {
        let windowEnd = windowEndDate(for: active, context: context, calendar: input.calendar)
        let explanation = "\(kind) is currently in effect.\(tow ? " Vehicles may be towed." : "")"
        return ParkingDecision(canPark: .no, legalUntil: nil, maxStayMinutes: nil, paymentStatus: .free,
                              explanation: explanation, nextChange: describeNextChange(windowEnd, calendar: input.calendar, dateTime: input.dateTime),
                              confidence: resolution.confidence, warnings: [warning], activeRestriction: active)
    }

    private static func makeZoneDecision(input: Input, active: ParkingRestriction, resolution: RestrictionResolver.ResolutionResult, context: RestrictionResolver.Context) -> ParkingDecision {
        let windowEnd = windowEndDate(for: active, context: context, calendar: input.calendar)
        let explanation = "This is a \(active.category.displayName.lowercased()). Only authorised vehicles may stop here."
        return ParkingDecision(canPark: .no, legalUntil: nil, maxStayMinutes: nil, paymentStatus: .free,
                              explanation: explanation, nextChange: describeNextChange(windowEnd, calendar: input.calendar, dateTime: input.dateTime),
                              confidence: resolution.confidence, warnings: ["This is a \(active.category.displayName.lowercased()). Only authorised vehicles may stop here."],
                              activeRestriction: active)
    }

    private static func makeLoadingZoneDecision(input: Input, active: ParkingRestriction, resolution: RestrictionResolver.ResolutionResult, context: RestrictionResolver.Context) -> ParkingDecision {
        let windowEnd = windowEndDate(for: active, context: context, calendar: input.calendar)
        var warnings = ["Loading zone: you may stop only to load or unload goods."]
        if let minutes = active.maxStayMinutes { warnings.append("Maximum stay for loading/unloading: \(minutes) minutes.") }
        return ParkingDecision(canPark: .no, legalUntil: nil, maxStayMinutes: active.maxStayMinutes, paymentStatus: .free,
                              explanation: "Loading zone is currently active. Only loading and unloading of goods is permitted.",
                              nextChange: describeNextChange(windowEnd, calendar: input.calendar, dateTime: input.dateTime),
                              confidence: resolution.confidence, warnings: warnings, activeRestriction: active)
    }

    private static func makePermitZoneDecision(input: Input, active: ParkingRestriction, resolution: RestrictionResolver.ResolutionResult, context: RestrictionResolver.Context) -> ParkingDecision {
        let windowEnd = windowEndDate(for: active, context: context, calendar: input.calendar)
        if input.hasPermit {
            return ParkingDecision(canPark: .yes, legalUntil: windowEnd, maxStayMinutes: nil, paymentStatus: .free,
                                  explanation: "Permit zone. Your permit allows parking here.",
                                  nextChange: describeNextChange(windowEnd, calendar: input.calendar, dateTime: input.dateTime),
                                  confidence: resolution.confidence, warnings: ["Permit zone: ensure your permit is displayed."],
                                  activeRestriction: active)
        }
        return ParkingDecision(canPark: .no, legalUntil: nil, maxStayMinutes: nil, paymentStatus: .free,
                              explanation: "Permit holders only. You need a valid permit to park here.",
                              nextChange: describeNextChange(windowEnd, calendar: input.calendar, dateTime: input.dateTime),
                              confidence: resolution.confidence, warnings: ["Permit holders only. You need a valid permit to park here."],
                              activeRestriction: active)
    }

    private static func makeTimedParkingDecision(input: Input, active: ParkingRestriction, resolution: RestrictionResolver.ResolutionResult, context: RestrictionResolver.Context) -> ParkingDecision {
        let windowEnd = windowEndDate(for: active, context: context, calendar: input.calendar)
        let paymentStatus: PaymentStatus = active.paymentType == .none ? .free : (active.paymentType == .unknown ? .unknown : .paid)

        var legalUntil: Date? = windowEnd
        if let maxStay = active.maxStayMinutes {
            let maxStayEnd = input.calendar.date(byAdding: .minute, value: maxStay, to: input.dateTime)
            if let msEnd = maxStayEnd {
                if let wEnd = windowEnd { legalUntil = min(msEnd, wEnd) }
                else { legalUntil = msEnd }
            }
        }

        var warnings: [String] = []
        if let windowEndDate = windowEnd {
            let minutesRemaining = Int(windowEndDate.timeIntervalSince(input.dateTime) / 60.0)
            if minutesRemaining <= 15 && minutesRemaining > 0 {
                warnings.append("The parking window ends in \(minutesRemaining) minutes. You may not have enough time.")
            }
        }
        if paymentStatus == .paid {
            let paymentName: String
            switch active.paymentType {
            case .meter: paymentName = "meter"
            case .ticket: paymentName = "ticket machine"
            case .payHere: paymentName = "pay station"
            case .app: paymentName = "parking app"
            default: paymentName = "payment"
            }
            warnings.append("Payment required: use the \(paymentName).")
        }

        var explanationParts: [String] = ["You can park here."]
        if let maxStay = active.maxStayMinutes { explanationParts.append("Maximum stay: \(maxStay / 60 > 0 ? "\(maxStay / 60) hour\(maxStay / 60 == 1 ? "" : "s")" : "\(maxStay) minutes").") }
        if paymentStatus == .paid { explanationParts.append("Payment is required.") }

        return ParkingDecision(canPark: .yes, legalUntil: legalUntil, maxStayMinutes: active.maxStayMinutes, paymentStatus: paymentStatus,
                              explanation: explanationParts.joined(separator: " "),
                              nextChange: describeNextChange(windowEnd, calendar: input.calendar, dateTime: input.dateTime),
                              confidence: resolution.confidence, warnings: warnings, activeRestriction: active)
    }

    private static func makeExemptDecision(input: Input, active: ParkingRestriction, resolution: RestrictionResolver.ResolutionResult, context: RestrictionResolver.Context) -> ParkingDecision {
        let windowEnd = windowEndDate(for: active, context: context, calendar: input.calendar)
        return ParkingDecision(canPark: .yes, legalUntil: windowEnd, maxStayMinutes: nil, paymentStatus: .free,
                              explanation: "Your vehicle type (\(input.vehicleType.rawValue)) is exempt from this restriction.",
                              nextChange: describeNextChange(windowEnd, calendar: input.calendar, dateTime: input.dateTime),
                              confidence: resolution.confidence * 0.9,
                              warnings: ["You appear to be exempt, but please verify the sign applies to your vehicle type."],
                              activeRestriction: active)
    }

    private static func makePermitExemptDecision(input: Input, active: ParkingRestriction, resolution: RestrictionResolver.ResolutionResult, context: RestrictionResolver.Context) -> ParkingDecision {
        let windowEnd = windowEndDate(for: active, context: context, calendar: input.calendar)
        return ParkingDecision(canPark: .yes, legalUntil: windowEnd, maxStayMinutes: nil, paymentStatus: .free,
                              explanation: "Permit holders are exempt from this restriction. Ensure your permit is displayed.",
                              nextChange: describeNextChange(windowEnd, calendar: input.calendar, dateTime: input.dateTime),
                              confidence: resolution.confidence * 0.85,
                              warnings: ["Ensure your permit is clearly displayed on your vehicle."],
                              activeRestriction: active)
    }

    private static func makeUncertainDecision(resolution: RestrictionResolver.ResolutionResult) -> ParkingDecision {
        ParkingDecision(canPark: .uncertain, legalUntil: nil, maxStayMinutes: nil, paymentStatus: .unknown,
                       explanation: "Unable to determine parking rules from the sign text. Please read the sign carefully.",
                       nextChange: "Unknown", confidence: 0.2,
                       warnings: ["The sign could not be fully interpreted. Please check the sign manually."],
                       activeRestriction: nil)
    }

    // MARK: - Helpers

    private static func isExempt(vehicleType: VehicleType, exemptions: [Exemption]) -> Bool {
        for exemption in exemptions {
            switch (exemption, vehicleType) {
            case (.buses, .bus), (.taxis, .taxi), (.trucks, .truck),
                 (.motorcycles, .motorcycle), (.bicycles, .bicycle), (.emergencyVehicles, .emergency): return true
            default: continue
            }
        }
        return false
    }

    private static func windowEndDate(for restriction: ParkingRestriction, context: RestrictionResolver.Context, calendar: Calendar) -> Date? {
        guard let window = restriction.timeWindows.first(where: { $0.contains(date: context.dateTime, calendar: calendar,
                                                                                isSchoolDay: context.isSchoolDay, isPublicHoliday: context.isPublicHoliday) }) else { return nil }
        var components = calendar.dateComponents([.year, .month, .day], from: context.dateTime)
        components.hour = window.endTime.hour; components.minute = window.endTime.minute; components.second = 0
        return calendar.date(from: components)
    }

    private static func describeNextChange(_ nextDate: Date?, calendar: Calendar, dateTime: Date) -> String {
        guard let next = nextDate else { return "No upcoming changes detected." }
        let minutesAway = Int(next.timeIntervalSince(dateTime) / 60.0)
        if minutesAway <= 0 { return "A change is happening now." }
        if minutesAway < 60 { return "Rules change in \(minutesAway) minute\(minutesAway == 1 ? "" : "s")." }
        let hours = minutesAway / 60
        let mins = minutesAway % 60
        if mins == 0 { return "Rules change in \(hours) hour\(hours == 1 ? "" : "s")." }
        return "Rules change in \(hours) hour\(hours == 1 ? "" : "s") and \(mins) minute\(mins == 1 ? "" : "s")."
    }
}
