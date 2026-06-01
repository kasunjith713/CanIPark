# Maintenance Playbook

This document describes how to update each component of CanIPark when rules, data, or sign formats change.

## Adding a New Sign Category

### When to do this
A new type of parking sign is introduced (e.g., a new zone type or restriction category).

### Steps

1. **Add the enum case** in `CanIPark/Models/ParkingModels.swift`:
   - Add a new case to `SignCategory`
   - Set its `precedence` value (lower = more restrictive)
   - Add a `displayName`

2. **Add detection logic** in `CanIPark/Parser/SignTextParser.swift`:
   - Add a regex pattern to `detectCategory()` matching the sign's text
   - Return the new category with an appropriate confidence score
   - If the sign includes a timed duration, call `parseTimedDuration()`

3. **Add a decision builder** in `CanIPark/Engine/ParkingDecisionEngine.swift`:
   - Add a `case` to the `switch active.category` block in `decide(input:)`
   - Create a private `make___Decision()` method following the existing patterns
   - Decide on the `canPark` value, payment status, warnings, and explanation

4. **Update the explanation** in `CanIPark/Engine/ExplanationGenerator.swift`:
   - Add a `case` to the `switch category` block in `generateExplanation()`

5. **Add the sign type to the database** in `CanIPark/Database/schema.sql`:
   - Insert a row into `sign_types`
   - Add any associated `restriction_rules`

6. **Write tests**:
   - Add parser tests in `CanIParkTests/SignTextParserTests.swift`
   - Add decision engine tests in `CanIParkTests/ParkingDecisionEngineTests.swift`

7. **Update documentation**:
   - Add the sign type to the table in `README.md`
   - Add any edge cases to `docs/edge_cases.md`

## Adding a New Exemption Type

### When to do this
A new vehicle exemption appears on signs (e.g., scooters, rideshare vehicles).

### Steps

1. **Add the enum case** in `CanIPark/Models/ParkingModels.swift`:
   - Add a new case to `Exemption`

2. **Add detection logic** in `CanIPark/Parser/SignTextParser.swift`:
   - Add regex patterns to `detectExemptions()` for the new exemption text

3. **Add exemption mapping** in `CanIPark/Engine/ParkingDecisionEngine.swift`:
   - If the exemption corresponds to a `VehicleType`, add the mapping to `isExempt()`
   - If it is a new vehicle type, add a case to `VehicleType` as well

4. **Write tests** covering the new exemption in parser and engine test files.

## Adding a New Payment Type

### When to do this
A new payment method appears on signs (e.g., contactless, QR code).

### Steps

1. **Add the enum case** in `CanIPark/Models/ParkingModels.swift`:
   - Add a new case to `PaymentType`

2. **Add detection logic** in `CanIPark/Parser/SignTextParser.swift`:
   - Add regex patterns to `detectPaymentType()` for the new payment text

3. **Update the decision engine** in `CanIPark/Engine/ParkingDecisionEngine.swift`:
   - Add a case for the new payment type in `makeTimedParkingDecision()` where the payment name is determined

4. **Write tests** in `SignTextParserTests.swift` and `ParkingDecisionEngineTests.swift`.

## Updating Public Holiday Data

### When to do this
At the start of each calendar year, or whenever public holiday dates are gazetted or changed.

### Current approach
The app accepts a boolean `isPublicHoliday` flag from the caller. The app itself does not maintain a public holiday database. If you add one:

### Steps to add a built-in holiday calendar

1. **Create a holiday data source**:
   - Add a `PublicHolidayCalendar.swift` file in `CanIPark/Engine/`
   - Include fixed-date holidays (New Year, Australia Day, Anzac Day, Christmas, Boxing Day)
   - Include computed holidays (Easter, Queen's Birthday by state)
   - Include state-specific holidays (Melbourne Cup, Recreation Day, etc.)

2. **Update the database schema**:
   - The `public_holidays` table in `schema.sql` is already defined
   - Insert rows for each jurisdiction and year

3. **Integrate with the decision engine**:
   - Query the holiday calendar in `ParkingDecisionEngine.decideFromText()` to set `isPublicHoliday` automatically based on the device location

4. **Update annually**:
   - Some holidays (e.g., Easter) have different dates each year
   - Some state holidays change (e.g., Queen's Birthday may become King's Birthday)
   - Publish an app update or use a remote config mechanism

## Updating School Term Dates

### When to do this
Before the start of each school year, or when term dates are published.

### Steps

1. **Obtain term dates** from each state/territory's education department.

2. **Create or update a school calendar data source** similar to the holiday calendar.

3. **Integrate with the decision engine** so `isSchoolDay` is set automatically.

4. **Account for variations**: Public schools, Catholic schools, and independent schools may have different term dates.

## Adding OCR Error Corrections

### When to do this
When users report consistent misreadings of specific words.

### Steps

1. **Add a correction entry** in `SignTextParser.preprocessText()`:
   ```swift
   (#"(?i)\bMISREAD\b"#, "CORRECT"),
   ```

2. **Test the correction** does not interfere with legitimate text that happens to contain the misread pattern.

3. **Document the correction** in code comments explaining which OCR engine/scenario produces the misread.

## Adding Time Format Support

### When to do this
When a new time format is encountered on parking signs.

### Steps

1. **Add a regex pattern** in `TimeWindowParser.parseTimeRanges()`:
   - Follow the existing pattern of trying AM/PM format first, then military time
   - Add the new format as an additional fallback

2. **Write tests** in `TimeWindowParserTests.swift` covering the new format.

## Database Schema Changes

### Steps

1. **Update the schema** in `CanIPark/Database/schema.sql`.

2. **Add a migration** if the app is already in production:
   - Create a versioned migration script
   - Update the schema version number
   - Handle both fresh installs and upgrades

3. **Update the data model documentation** in `docs/data_model.md`.

## Updating the Confidence Model

### When to do this
When user feedback indicates that confidence scores are miscalibrated (too many false positives or false negatives at a given confidence level).

### Steps

1. **Review the scoring logic** in:
   - `SignTextParser.computeConfidence()` (parser-level confidence)
   - `RestrictionResolver.computeResolutionConfidence()` (resolution-level confidence)
   - `RestrictionResolver.computeUnrestrictedConfidence()` (unrestricted state confidence)

2. **Adjust weights and thresholds** based on collected data.

3. **Update the confidence level boundaries** in `ConfidenceLevel.init(from:)` if the mapping from score to high/medium/low needs recalibration.

4. **Run the full test suite** to ensure no regressions.

## Release Checklist

Before each release:

- [ ] All tests pass
- [ ] Public holiday data is current for the next 12 months (if built in)
- [ ] School term dates are current (if built in)
- [ ] Any new sign types encountered since last release are handled
- [ ] OCR error correction list is updated based on user reports
- [ ] Known limitations document is current
- [ ] App Store description is updated if features changed
- [ ] Legal disclaimer is reviewed
