// ParkingModels.swift
// CanIPark
//
// Shared data models for the parking sign interpretation engine.

import Foundation

// MARK: - Sign Category

enum SignCategory: String, Codable, CaseIterable {
    case timedParking
    case noParking
    case noStopping
    case clearway
    case loadingZone
    case busZone
    case taxiZone
    case truckZone
    case worksZone
    case mailZone
    case permitZone
    case accessible
    case evCharging
    case unrestricted
    case unknown

    var precedence: Int {
        switch self {
        case .noStopping:    return 0
        case .clearway:      return 1
        case .noParking:     return 2
        case .busZone:       return 3
        case .taxiZone:      return 4
        case .truckZone:     return 5
        case .worksZone:     return 6
        case .mailZone:      return 7
        case .loadingZone:   return 8
        case .permitZone:    return 9
        case .accessible:    return 9
        case .evCharging:    return 9
        case .timedParking:  return 10
        case .unrestricted:  return 99
        case .unknown:       return 100
        }
    }

    var displayName: String {
        switch self {
        case .timedParking:  return "Timed Parking"
        case .noParking:     return "No Parking"
        case .noStopping:    return "No Stopping"
        case .clearway:      return "Clearway"
        case .loadingZone:   return "Loading Zone"
        case .busZone:       return "Bus Zone"
        case .taxiZone:      return "Taxi Zone"
        case .truckZone:     return "Truck Zone"
        case .worksZone:     return "Works Zone"
        case .mailZone:      return "Mail Zone"
        case .permitZone:    return "Permit Zone"
        case .accessible:    return "Accessible Parking"
        case .evCharging:    return "EV Charging Only"
        case .unrestricted:  return "Unrestricted"
        case .unknown:       return "Unknown"
        }
    }
}

// MARK: - Arrow Direction

enum ArrowDirection: String, Codable {
    case left
    case right
    case both
    case none
}

// MARK: - Payment Type

enum PaymentType: String, Codable {
    case meter
    case ticket
    case payHere
    case app
    case none
    case unknown
}

// MARK: - Day of Week

enum DayOfWeek: Int, Codable, CaseIterable, Comparable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    static func < (lhs: DayOfWeek, rhs: DayOfWeek) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var abbreviation: String {
        switch self {
        case .sunday:    return "Sun"
        case .monday:    return "Mon"
        case .tuesday:   return "Tue"
        case .wednesday: return "Wed"
        case .thursday:  return "Thu"
        case .friday:    return "Fri"
        case .saturday:  return "Sat"
        }
    }

    var fullName: String {
        switch self {
        case .sunday:    return "Sunday"
        case .monday:    return "Monday"
        case .tuesday:   return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday:  return "Thursday"
        case .friday:    return "Friday"
        case .saturday:  return "Saturday"
        }
    }

    static func fromCalendarWeekday(_ weekday: Int) -> DayOfWeek? {
        return DayOfWeek(rawValue: weekday)
    }

    static let weekdays: Set<DayOfWeek> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    static let weekend: Set<DayOfWeek> = [.saturday, .sunday]
    static let allDays: Set<DayOfWeek> = Set(DayOfWeek.allCases)
}

// MARK: - Public Holiday Behavior

enum PublicHolidayBehavior: String, Codable {
    case applies
    case doesNotApply
    case publicHolidayOnly
    case unspecified
}

// MARK: - Time of Day

struct TimeOfDay: Codable, Equatable, Comparable {
    let hour: Int
    let minute: Int

    var totalMinutes: Int { hour * 60 + minute }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.totalMinutes < rhs.totalMinutes
    }

    var formatted: String {
        let isPM = hour >= 12
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let suffix = isPM ? "PM" : "AM"
        if minute == 0 {
            return "\(displayHour):00 \(suffix)"
        }
        return String(format: "%d:%02d %@", displayHour, minute, suffix)
    }

    static let midnight = TimeOfDay(hour: 0, minute: 0)
    static let endOfDay = TimeOfDay(hour: 23, minute: 59)
    static let noon = TimeOfDay(hour: 12, minute: 0)
}

// MARK: - Time Window

struct TimeWindow: Codable, Equatable {
    let startTime: TimeOfDay
    let endTime: TimeOfDay
    let daysOfWeek: Set<DayOfWeek>
    let schoolDaysOnly: Bool
    let publicHolidayBehavior: PublicHolidayBehavior

    var isAllDay: Bool {
        startTime == TimeOfDay.midnight && endTime == TimeOfDay.endOfDay
    }

    var isEveryDay: Bool {
        daysOfWeek == DayOfWeek.allDays
    }

    static let always = TimeWindow(
        startTime: .midnight,
        endTime: .endOfDay,
        daysOfWeek: DayOfWeek.allDays,
        schoolDaysOnly: false,
        publicHolidayBehavior: .unspecified
    )

    func contains(date: Date, calendar: Calendar = .current, isSchoolDay: Bool = false, isPublicHoliday: Bool = false) -> Bool {
        switch publicHolidayBehavior {
        case .doesNotApply:
            if isPublicHoliday { return false }
        case .publicHolidayOnly:
            if !isPublicHoliday { return false }
        case .applies, .unspecified:
            break
        }

        if schoolDaysOnly && !isSchoolDay {
            return false
        }

        let weekday = calendar.component(.weekday, from: date)
        guard let day = DayOfWeek.fromCalendarWeekday(weekday) else { return false }
        if !daysOfWeek.contains(day) { return false }

        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let currentTime = TimeOfDay(hour: hour, minute: minute)

        return currentTime >= startTime && currentTime <= endTime
    }
}

// MARK: - Exemption

enum Exemption: String, Codable {
    case buses
    case taxis
    case trucks
    case permitHolders
    case disabilityPermit
    case emergencyVehicles
    case motorcycles
    case bicycles
    case electricVehicles
}

// MARK: - Parking Restriction

struct ParkingRestriction: Codable {
    let category: SignCategory
    let maxStayMinutes: Int?
    let timeWindows: [TimeWindow]
    let paymentType: PaymentType
    let exemptions: [Exemption]
    let arrowDirection: ArrowDirection
    let rawText: String
    let confidence: Double

    func isActive(at date: Date, calendar: Calendar = .current, isSchoolDay: Bool = false, isPublicHoliday: Bool = false) -> Bool {
        if timeWindows.isEmpty {
            return true
        }
        return timeWindows.contains { window in
            window.contains(date: date, calendar: calendar, isSchoolDay: isSchoolDay, isPublicHoliday: isPublicHoliday)
        }
    }
}

// MARK: - Parking Ability

enum ParkingAbility: String, Codable {
    case yes
    case no
    case uncertain
}

// MARK: - Payment Status

enum PaymentStatus: String, Codable {
    case free
    case paid
    case unknown
}

// MARK: - Confidence Level

enum ConfidenceLevel: String, Codable {
    case high
    case medium
    case low

    var displayName: String { rawValue.capitalized }

    var color: String {
        switch self {
        case .high:   return "green"
        case .medium: return "orange"
        case .low:    return "red"
        }
    }

    var iconName: String {
        switch self {
        case .high:   return "checkmark.shield.fill"
        case .medium: return "exclamationmark.shield.fill"
        case .low:    return "xmark.shield.fill"
        }
    }

    init(from score: Double) {
        if score >= 0.75 { self = .high }
        else if score >= 0.5 { self = .medium }
        else { self = .low }
    }
}

// MARK: - Parking Decision

struct ParkingDecision: Codable {
    let canPark: ParkingAbility
    let legalUntil: Date?
    let maxStayMinutes: Int?
    let paymentStatus: PaymentStatus
    let explanation: String
    let nextChange: String
    let confidence: Double
    let warnings: [String]
    let activeRestriction: ParkingRestriction?

    var confidenceLevel: ConfidenceLevel { ConfidenceLevel(from: confidence) }
}

// MARK: - Verdict

enum Verdict: String, Codable {
    case canPark
    case cannotPark
    case uncertain

    var headline: String {
        switch self {
        case .canPark:    return "You Can Park Here"
        case .cannotPark: return "You Cannot Park Here"
        case .uncertain:  return "Not Enough Information"
        }
    }

    var iconName: String {
        switch self {
        case .canPark:    return "checkmark.circle.fill"
        case .cannotPark: return "xmark.circle.fill"
        case .uncertain:  return "questionmark.circle.fill"
        }
    }

    var colorName: String {
        switch self {
        case .canPark:    return "green"
        case .cannotPark: return "red"
        case .uncertain:  return "orange"
        }
    }
}

// MARK: - Analysis Result (UI model)

struct ParkingAnalysisResult: Identifiable, Codable {
    let id: UUID
    let verdict: Verdict
    let confidence: ConfidenceLevel
    let timeLimit: String?
    let maxStay: String?
    let paymentStatus: String?
    let warnings: [String]
    let detectedSigns: [DetectedSign]
    let reasoningChain: [String]
    let scanDate: Date
    let locationDescription: String?

    init(
        id: UUID = UUID(),
        verdict: Verdict,
        confidence: ConfidenceLevel,
        timeLimit: String? = nil,
        maxStay: String? = nil,
        paymentStatus: String? = nil,
        warnings: [String] = [],
        detectedSigns: [DetectedSign] = [],
        reasoningChain: [String] = [],
        scanDate: Date = Date(),
        locationDescription: String? = nil
    ) {
        self.id = id
        self.verdict = verdict
        self.confidence = confidence
        self.timeLimit = timeLimit
        self.maxStay = maxStay
        self.paymentStatus = paymentStatus
        self.warnings = warnings
        self.detectedSigns = detectedSigns
        self.reasoningChain = reasoningChain
        self.scanDate = scanDate
        self.locationDescription = locationDescription
    }
}

// MARK: - Detected Sign (UI model)

struct DetectedSign: Identifiable, Codable {
    let id: UUID
    let ocrText: String
    let parsedRestriction: String
    let boundingBox: CGRect?
    let confidence: Double
    let arrowDirection: String?

    init(
        id: UUID = UUID(),
        ocrText: String,
        parsedRestriction: String,
        boundingBox: CGRect? = nil,
        confidence: Double = 0.0,
        arrowDirection: String? = nil
    ) {
        self.id = id
        self.ocrText = ocrText
        self.parsedRestriction = parsedRestriction
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.arrowDirection = arrowDirection
    }
}
