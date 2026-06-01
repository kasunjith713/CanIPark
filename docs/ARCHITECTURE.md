# Architecture

## Module Diagram

```
+------------------------------------------------------------------+
|                          iOS App (SwiftUI)                        |
|                                                                   |
|  +------------------+    +------------------+    +--------------+ |
|  |   Camera View    |    |   Result View    |    | History View | |
|  +--------+---------+    +--------+---------+    +------+-------+ |
|           |                       ^                      ^        |
|           v                       |                      |        |
|  +--------+---------+             |              +-------+------+ |
|  |   Vision OCR     |             |              | ScanHistory  | |
|  |   (on-device)    |             |              |    Store     | |
|  +--------+---------+             |              +--------------+ |
|           |                       |                               |
|           v                       |                               |
|  +--------+------------------------------------------+            |
|  |              SignTextParser                       |            |
|  |  +--------------------------------------------+  |            |
|  |  |  - preprocessText (OCR error correction)   |  |            |
|  |  |  - splitIntoPanels                         |  |            |
|  |  |  - detectCategory                          |  |            |
|  |  |  - parseTimedDuration                      |  |            |
|  |  |  - detectPaymentType                       |  |            |
|  |  |  - detectExemptions                        |  |            |
|  |  |  - detectArrowDirection                    |  |            |
|  |  +--------------------------------------------+  |            |
|  |                                                   |            |
|  |  +--------------------------------------------+  |            |
|  |  |         TimeWindowParser                   |  |            |
|  |  |  - parseTimeRanges (AM/PM + military)      |  |            |
|  |  |  - parseDays (ranges + individual)         |  |            |
|  |  |  - parseSchoolDays                         |  |            |
|  |  |  - parsePublicHolidayBehavior              |  |            |
|  |  +--------------------------------------------+  |            |
|  +--------+------------------------------------------+            |
|           |                                                       |
|           | [ParkingRestriction]                                   |
|           v                                                       |
|  +--------+------------------------------------------+            |
|  |           ParkingDecisionEngine                   |            |
|  |                                                   |            |
|  |  +--------------------------------------------+  |            |
|  |  |        RestrictionResolver                 |  |            |
|  |  |  - resolve: find active restriction        |  |            |
|  |  |  - precedence-based conflict resolution    |  |            |
|  |  |  - nextChangeTime calculation              |  |            |
|  |  +--------------------------------------------+  |            |
|  |                                                   |            |
|  |  +--------------------------------------------+  |            |
|  |  |       ExplanationGenerator                 |  |            |
|  |  |  - generateExplanation                     |  |            |
|  |  |  - generateHeadline                        |  |            |
|  |  |  - describeDays                            |  |            |
|  |  +--------------------------------------------+  |            |
|  |                                                   |            |
|  |  Decision Builders:                               |            |
|  |  - makeUnrestrictedDecision                       |            |
|  |  - makeProhibitiveDecision (NoStop/Clearway/NoPk) |            |
|  |  - makeZoneDecision (Bus/Taxi/Truck/Works/Mail)   |            |
|  |  - makeLoadingZoneDecision                        |            |
|  |  - makePermitZoneDecision                         |            |
|  |  - makeTimedParkingDecision                       |            |
|  |  - makeExemptDecision                             |            |
|  |  - makeUncertainDecision                          |            |
|  +--------+------------------------------------------+            |
|           |                                                       |
|           | ParkingDecision                                       |
|           v                                                       |
|  +--------+---------+                                             |
|  |   Result View    |                                             |
|  +------------------+                                             |
+------------------------------------------------------------------+
```

## Data Flow

1. **Image Capture**: The camera view captures a photo of the parking sign.

2. **OCR Extraction**: Apple's Vision framework performs on-device text recognition on the captured image, producing raw OCR text.

3. **Text Preprocessing**: `SignTextParser.preprocessText` normalises line endings, replaces unicode dashes, and corrects common OCR misreads (e.g., `N0` to `NO`, `ST0PPING` to `STOPPING`).

4. **Panel Splitting**: `SignTextParser.splitIntoPanels` separates multi-panel signs (delimited by blank lines or separator characters) into individual text blocks.

5. **Category Detection**: Each panel is classified into a `SignCategory` (e.g., `.noStopping`, `.timedParking`, `.loadingZone`) using regex pattern matching. Timed durations are extracted (e.g., `2P` becomes 120 minutes).

6. **Time Window Parsing**: `TimeWindowParser.parse` extracts structured `TimeWindow` objects from the text, including:
   - Time ranges in AM/PM or 24-hour (military) format
   - Day-of-week ranges or individual days
   - School day flags
   - Public holiday behavior

7. **Supplementary Detection**: Payment type, exemptions, and arrow direction are detected from the same text.

8. **Restriction Assembly**: All parsed data is assembled into a `ParkingRestriction` object with a computed confidence score.

9. **Restriction Resolution**: `RestrictionResolver.resolve` evaluates all restrictions against the current date/time/context:
   - Filters to only currently active restrictions
   - Sorts by precedence (no stopping > clearway > no parking > zones > timed)
   - The highest-precedence active restriction "wins"

10. **Decision Generation**: `ParkingDecisionEngine` selects the appropriate decision builder based on the winning restriction's category, producing a `ParkingDecision` with:
    - `canPark`: yes, no, or uncertain
    - `legalUntil`: when parking legality changes
    - `maxStayMinutes`: how long you can stay
    - `paymentStatus`: free, paid, or unknown
    - `explanation`: human-readable rationale
    - `warnings`: actionable alerts
    - `confidence`: 0.0 to 1.0 reliability score

11. **Result Display**: The UI presents the verdict with color-coded status, time remaining, payment information, and any warnings.

12. **History Storage**: The scan result and optional thumbnail are persisted to `ScanHistoryStore` for later review.

## Design Decisions

### On-Device Processing
All OCR and decision logic runs on-device. This ensures the app works without an internet connection (critical for underground parking garages) and avoids sending user location or image data to external servers.

### Regex-Based Parsing
Australian parking signs follow standardised formats defined by Australian Standards (AS 1742.11). Regex-based parsing provides deterministic, auditable results compared to ML-based text interpretation. The patterns cover the full vocabulary of standard parking signs.

### Precedence-Based Conflict Resolution
When multiple restrictions are active simultaneously, the most restrictive one takes priority. This mirrors the legal reality: a "No Stopping" sign always overrides a "2P" sign on the same pole.

### Confidence Scoring
Every decision includes a confidence score (0.0-1.0) derived from:
- How clearly the sign category was matched
- Whether time windows were successfully parsed
- The quality/length of the OCR text
- Whether multiple conflicting restrictions were detected
- Proximity to time window boundaries

### Struct-Based Architecture
All models and engines are value types (structs) with static methods. This makes the parsing and decision logic easy to test in isolation without mocking dependencies.

### Immutable Data Flow
Data flows unidirectionally through the pipeline. Each stage receives input and produces output without side effects. The only mutable state is `ScanHistoryStore`, which is isolated from the decision logic.
