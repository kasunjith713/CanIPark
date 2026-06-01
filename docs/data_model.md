# Data Model Documentation

This document describes every data type used in the CanIPark application, its purpose, fields, and relationships.

## Enums

### SignCategory
Classification of a parking sign into one of the recognised Australian sign types.

| Case | Raw Value | Precedence | Description |
|---|---|---|---|
| `noStopping` | `"noStopping"` | 0 | No vehicle may stop at any time |
| `clearway` | `"clearway"` | 1 | No stopping; vehicles may be towed |
| `noParking` | `"noParking"` | 2 | No parking (brief stops up to 2 min permitted) |
| `busZone` | `"busZone"` | 3 | Reserved for buses |
| `taxiZone` | `"taxiZone"` | 4 | Reserved for taxis |
| `truckZone` | `"truckZone"` | 5 | Reserved for trucks |
| `worksZone` | `"worksZone"` | 6 | Reserved for works vehicles |
| `mailZone` | `"mailZone"` | 7 | Reserved for mail vehicles |
| `loadingZone` | `"loadingZone"` | 8 | Loading/unloading only |
| `permitZone` | `"permitZone"` | 9 | Permit holders only |
| `accessible` | `"accessible"` | 9 | Disability permit holders only |
| `evCharging` | `"evCharging"` | 9 | Electric vehicles while charging |
| `timedParking` | `"timedParking"` | 10 | Parking allowed with time limit |
| `unrestricted` | `"unrestricted"` | 99 | No restrictions |
| `unknown` | `"unknown"` | 100 | Could not be classified |

**Precedence**: Lower values indicate more restrictive categories. When multiple restrictions are active, the one with the lowest precedence wins.

### ArrowDirection
Direction indicated by arrows on the sign, specifying which side of the road the restriction applies to.

| Case | Description |
|---|---|
| `left` | Restriction applies to the left |
| `right` | Restriction applies to the right |
| `both` | Restriction applies in both directions |
| `none` | No arrow detected |

### PaymentType
Type of payment required for parking.

| Case | Description |
|---|---|
| `meter` | Parking meter |
| `ticket` | Ticket machine |
| `payHere` | Pay-and-display station |
| `app` | Mobile app payment |
| `none` | No payment required |
| `unknown` | Payment may be required but type is unclear |

### DayOfWeek
Days of the week, using Calendar weekday numbering (1 = Sunday through 7 = Saturday).

| Case | Raw Value | Abbreviation |
|---|---|---|
| `sunday` | 1 | Sun |
| `monday` | 2 | Mon |
| `tuesday` | 3 | Tue |
| `wednesday` | 4 | Wed |
| `thursday` | 5 | Thu |
| `friday` | 6 | Fri |
| `saturday` | 7 | Sat |

**Static Properties**:
- `weekdays`: Mon-Fri
- `weekend`: Sat-Sun
- `allDays`: All seven days

### PublicHolidayBehavior
How a restriction behaves on public holidays.

| Case | Description |
|---|---|
| `applies` | Restriction applies on public holidays (explicitly stated) |
| `doesNotApply` | Restriction does not apply on public holidays |
| `publicHolidayOnly` | Restriction only applies on public holidays |
| `unspecified` | Sign does not mention public holidays; restriction applies normally |

### Exemption
Vehicle or permit types that are exempt from a restriction.

| Case | Description |
|---|---|
| `buses` | Buses are exempt |
| `taxis` | Taxis are exempt |
| `trucks` | Trucks are exempt |
| `permitHolders` | Permit holders are exempt |
| `disabilityPermit` | Disability permit holders are exempt |
| `emergencyVehicles` | Emergency vehicles are exempt |
| `motorcycles` | Motorcycles are exempt |
| `bicycles` | Bicycles are exempt |
| `electricVehicles` | Electric vehicles are exempt |

### ParkingAbility
The top-level verdict on whether the user can park.

| Case | Description |
|---|---|
| `yes` | Parking is permitted |
| `no` | Parking is not permitted |
| `uncertain` | Unable to determine |

### PaymentStatus
Whether payment is required for parking.

| Case | Description |
|---|---|
| `free` | No payment required |
| `paid` | Payment is required |
| `unknown` | Cannot determine |

### ConfidenceLevel
Qualitative confidence in the decision.

| Case | Score Range | Color |
|---|---|---|
| `high` | >= 0.75 | Green |
| `medium` | 0.50 - 0.74 | Orange |
| `low` | < 0.50 | Red |

### Verdict
UI-level verdict for display purposes.

| Case | Headline | Color |
|---|---|---|
| `canPark` | "You Can Park Here" | Green |
| `cannotPark` | "You Cannot Park Here" | Red |
| `uncertain` | "Not Enough Information" | Orange |

### VehicleType
Type of vehicle, used for exemption matching.

| Case | Description |
|---|---|
| `car` | Standard passenger vehicle |
| `bus` | Bus |
| `taxi` | Taxi |
| `truck` | Truck |
| `motorcycle` | Motorcycle |
| `bicycle` | Bicycle |
| `emergency` | Emergency vehicle |

## Structs

### TimeOfDay
A time within a single day, represented as hours and minutes.

| Field | Type | Description |
|---|---|---|
| `hour` | `Int` | Hour (0-23) |
| `minute` | `Int` | Minute (0-59) |

**Computed Properties**:
- `totalMinutes`: Total minutes since midnight (`hour * 60 + minute`)
- `formatted`: Human-readable string (e.g., "8:00 AM", "5:30 PM")

**Static Values**:
- `midnight`: 00:00
- `endOfDay`: 23:59
- `noon`: 12:00

### TimeWindow
A time window during which a restriction applies, including day-of-week filtering and special day behavior.

| Field | Type | Description |
|---|---|---|
| `startTime` | `TimeOfDay` | Window start time |
| `endTime` | `TimeOfDay` | Window end time |
| `daysOfWeek` | `Set<DayOfWeek>` | Days this window applies |
| `schoolDaysOnly` | `Bool` | Only active on school days |
| `publicHolidayBehavior` | `PublicHolidayBehavior` | How this window behaves on public holidays |

**Computed Properties**:
- `isAllDay`: True if midnight to end-of-day
- `isEveryDay`: True if all seven days

**Methods**:
- `contains(date:calendar:isSchoolDay:isPublicHoliday:)`: Returns whether the given date/time falls within this window

### ParkingRestriction
A single parsed restriction from a parking sign panel.

| Field | Type | Description |
|---|---|---|
| `category` | `SignCategory` | Type of restriction |
| `maxStayMinutes` | `Int?` | Maximum parking duration in minutes |
| `timeWindows` | `[TimeWindow]` | When the restriction applies |
| `paymentType` | `PaymentType` | Required payment method |
| `exemptions` | `[Exemption]` | Exempt vehicle/permit types |
| `arrowDirection` | `ArrowDirection` | Directional arrow on sign |
| `rawText` | `String` | Original OCR text |
| `confidence` | `Double` | Parser confidence (0.0-1.0) |

**Methods**:
- `isActive(at:calendar:isSchoolDay:isPublicHoliday:)`: Returns whether this restriction is currently active

### ParkingDecision
The engine's output: a complete decision about whether parking is permitted.

| Field | Type | Description |
|---|---|---|
| `canPark` | `ParkingAbility` | Yes, no, or uncertain |
| `legalUntil` | `Date?` | When parking legality changes |
| `maxStayMinutes` | `Int?` | Maximum stay duration |
| `paymentStatus` | `PaymentStatus` | Free, paid, or unknown |
| `explanation` | `String` | Human-readable explanation |
| `nextChange` | `String` | Description of next rule change |
| `confidence` | `Double` | Decision confidence (0.0-1.0) |
| `warnings` | `[String]` | Actionable warnings for the user |
| `activeRestriction` | `ParkingRestriction?` | The restriction driving this decision |

**Computed Properties**:
- `confidenceLevel`: Maps confidence score to `ConfidenceLevel`

### ParkingAnalysisResult
UI-level model for displaying and persisting a complete scan result.

| Field | Type | Description |
|---|---|---|
| `id` | `UUID` | Unique identifier |
| `verdict` | `Verdict` | Can park / cannot park / uncertain |
| `confidence` | `ConfidenceLevel` | High / medium / low |
| `timeLimit` | `String?` | Display string for time limit |
| `maxStay` | `String?` | Display string for maximum stay |
| `paymentStatus` | `String?` | Display string for payment |
| `warnings` | `[String]` | Warning messages |
| `detectedSigns` | `[DetectedSign]` | Individual signs detected |
| `reasoningChain` | `[String]` | Step-by-step reasoning |
| `scanDate` | `Date` | When the scan was performed |
| `locationDescription` | `String?` | Human-readable location |

### DetectedSign
A single sign detected within a scan, used for UI display.

| Field | Type | Description |
|---|---|---|
| `id` | `UUID` | Unique identifier |
| `ocrText` | `String` | Raw OCR text |
| `parsedRestriction` | `String` | Human-readable parsed restriction |
| `boundingBox` | `CGRect?` | Position in the image |
| `confidence` | `Double` | Detection confidence |
| `arrowDirection` | `String?` | Arrow direction description |

## Internal Engine Types

### ParkingDecisionEngine.Input
Input bundle for the decision engine.

| Field | Type | Default | Description |
|---|---|---|---|
| `restrictions` | `[ParkingRestriction]` | (required) | Parsed restrictions |
| `dateTime` | `Date` | `Date()` | Current date/time |
| `calendar` | `Calendar` | `.current` | Calendar for date calculations |
| `isSchoolDay` | `Bool` | `false` | Whether today is a school day |
| `isPublicHoliday` | `Bool` | `false` | Whether today is a public holiday |
| `hasPermit` | `Bool` | `false` | Whether user has a parking permit |
| `vehicleType` | `VehicleType` | `.car` | User's vehicle type |

### RestrictionResolver.ResolutionResult
Result of resolving which restriction(s) are currently active.

| Field | Type | Description |
|---|---|---|
| `activeRestriction` | `ParkingRestriction?` | Winning restriction |
| `activeTimeWindow` | `TimeWindow?` | Active window of winning restriction |
| `confidence` | `Double` | Resolution confidence |
| `allActiveRestrictions` | `[ParkingRestriction]` | All currently active restrictions |
| `isUnrestricted` | `Bool` | True if no restrictions are active |

### RestrictionResolver.Context
Date/time context for restriction evaluation.

| Field | Type | Default | Description |
|---|---|---|---|
| `dateTime` | `Date` | (required) | Current date/time |
| `calendar` | `Calendar` | `.current` | Calendar for date calculations |
| `isSchoolDay` | `Bool` | `false` | School day flag |
| `isPublicHoliday` | `Bool` | `false` | Public holiday flag |

## Relationships

```
ParkingAnalysisResult
  |-- Verdict
  |-- ConfidenceLevel
  |-- [DetectedSign]

ParkingDecision
  |-- ParkingAbility
  |-- PaymentStatus
  |-- ParkingRestriction (optional)
      |-- SignCategory
      |-- [TimeWindow]
      |   |-- TimeOfDay (start)
      |   |-- TimeOfDay (end)
      |   |-- Set<DayOfWeek>
      |   |-- PublicHolidayBehavior
      |-- PaymentType
      |-- [Exemption]
      |-- ArrowDirection

ParkingDecisionEngine.Input
  |-- [ParkingRestriction]
  |-- VehicleType

RestrictionResolver.ResolutionResult
  |-- ParkingRestriction (optional)
  |-- TimeWindow (optional)
  |-- [ParkingRestriction]
```
