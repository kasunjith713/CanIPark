# Project Structure

```
CanIPark/
|
|-- README.md                          Project overview, features, build instructions
|
|-- CanIPark/                          Main application source
|   |
|   |-- Models/
|   |   |-- ParkingModels.swift        All shared data types: SignCategory, TimeWindow,
|   |                                  ParkingRestriction, ParkingDecision, Verdict,
|   |                                  ParkingAnalysisResult, DetectedSign, enums
|   |
|   |-- Parser/
|   |   |-- SignTextParser.swift       Parses OCR text into ParkingRestriction objects.
|   |   |                              Handles: category detection, duration parsing,
|   |   |                              payment type, exemptions, arrow direction,
|   |   |                              OCR error correction, multi-panel splitting.
|   |   |
|   |   |-- TimeWindowParser.swift     Parses time ranges (AM/PM, military), day ranges,
|   |                                  school day flags, and public holiday behavior
|   |                                  into TimeWindow objects.
|   |
|   |-- Engine/
|   |   |-- ParkingDecisionEngine.swift  Main decision engine. Takes ParkingRestriction
|   |   |                                array + context, produces ParkingDecision.
|   |   |                                Includes decideFromText() convenience method.
|   |   |
|   |   |-- RestrictionResolver.swift    Determines which restrictions are active at a
|   |   |                                given date/time. Handles precedence-based
|   |   |                                conflict resolution and next-change-time
|   |   |                                calculation.
|   |   |
|   |   |-- ExplanationGenerator.swift   Generates human-readable explanations and
|   |                                    headlines from decision data. Formats day
|   |                                    ranges and time windows for display.
|   |
|   |-- Storage/
|   |   |-- ScanHistoryStore.swift       Persists scan results to UserDefaults as JSON.
|   |                                    Manages thumbnail images on disk (JPEG in
|   |                                    Caches directory). Observable for SwiftUI.
|   |
|   |-- Database/
|   |   |-- schema.sql                   SQLite schema defining tables for jurisdictions,
|   |                                    sign types, restriction rules, time windows,
|   |                                    public holidays, and scan history. Includes
|   |                                    seed data for Australian states and common
|   |                                    sign types.
|   |
|   |-- Info.plist                       Privacy usage descriptions for camera, location,
|                                        and photo library access.
|
|-- CanIParkTests/                     Unit tests
|   |-- SignTextParserTests.swift       50+ tests for sign text parsing: categories,
|   |                                   durations, payments, exemptions, arrows, OCR
|   |                                   correction, multi-panel, confidence, edge cases.
|   |
|   |-- TimeWindowParserTests.swift    30+ tests for time/day parsing: AM/PM, military
|   |                                   time, day ranges, school days, public holidays,
|   |                                   multiple ranges, boundary conditions.
|   |
|   |-- ParkingDecisionEngineTests.swift 40+ scenario tests: timed parking, no stopping,
|   |                                   clearway, loading zones, special zones, permit
|   |                                   zones, public holidays, school days, payments,
|   |                                   near-window-end, vehicle exemptions, confidence.
|   |
|   |-- PublicHolidayTests.swift       20+ tests for public holiday handling: window
|                                       behavior, restriction activity, engine decisions,
|                                       known holidays, edge cases.
|
|-- docs/                              Documentation
|   |-- ARCHITECTURE.md                Module diagram (ASCII), data flow, design decisions
|   |-- KNOWN_LIMITATIONS.md           30 documented limitations organized by category
|   |-- LEGAL_DISCLAIMER.md            User-facing legal disclaimer
|   |-- MAINTENANCE.md                 Update playbook for rules, holidays, sign types
|   |-- edge_cases.md                  58 edge cases organized by category
|   |-- failure_modes.md               25 failure modes with causes and mitigations
|   |-- data_model.md                  Complete data model documentation
|   |-- APP_STORE_DESCRIPTION.md       App Store listing copy
|   |-- PROJECT_STRUCTURE.md           This file
|   |
|   |-- research/
|   |   |-- australian_parking_rules_research.md
|   |                                   Research dossier: official sources, sign taxonomy,
|   |                                   state differences, public holiday handling,
|   |                                   enforcement details.
|   |
|   |-- screenshots/                   (Directory for app screenshots)
```

## Module Dependencies

```
SignTextParser
  |-- TimeWindowParser         (called internally for time/day parsing)

ParkingDecisionEngine
  |-- SignTextParser            (via decideFromText convenience method)
  |-- RestrictionResolver       (resolves active restrictions)
  |-- ExplanationGenerator      (not directly called; available for UI)

ScanHistoryStore
  |-- ParkingAnalysisResult     (stored model)

All modules depend on:
  |-- ParkingModels             (shared types)
```
