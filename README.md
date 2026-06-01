# CanIPark

An iOS app that uses your phone's camera to read Australian parking signs and instantly tells you whether you can park, for how long, and whether payment is required.

## Overview

CanIPark solves the universal frustration of deciphering complex parking signage. Point your camera at a parking sign, and the app will:

1. Capture the sign image using the device camera
2. Extract text via on-device OCR (Vision framework)
3. Parse the text into structured parking restrictions
4. Evaluate the restrictions against the current date, time, and context
5. Deliver a clear verdict: **You Can Park Here** or **You Cannot Park Here**

## Features

- **Real-time sign scanning** using the device camera
- **On-device OCR** with no internet connection required for basic functionality
- **Comprehensive sign support** covering the full range of Australian parking signage
- **Time-aware decisions** that account for current day of week, time, and public holidays
- **School day awareness** for school zone restrictions
- **Payment detection** identifying meter, ticket, pay-and-display, and app-based payment
- **Exemption handling** for buses, taxis, trucks, permit holders, disability permits, and more
- **Multi-panel sign parsing** for signs with multiple restriction blocks
- **OCR error correction** to handle common misreads (0/O, l/I, etc.)
- **Scan history** with thumbnails for reviewing past scans
- **Arrow direction detection** to understand which side of the road the sign applies to
- **Confidence scoring** so you know how reliable the interpretation is

## Supported Sign Types

| Category | Examples |
|---|---|
| Timed Parking | 1P, 2P, 4P, 1/2P, 1/4P, 15 MIN, 2 HOURS |
| No Stopping | NO STOPPING (with or without time windows) |
| No Parking | NO PARKING (with or without time windows) |
| Clearway | CLEARWAY (tow-away warning included) |
| Loading Zone | LOADING ZONE, LOADING ZONE 15 MIN |
| Bus Zone | BUS ZONE |
| Taxi Zone | TAXI ZONE |
| Truck Zone | TRUCK ZONE |
| Works Zone | WORKS ZONE |
| Mail Zone | MAIL ZONE |
| Permit Zone | PERMIT ZONE, PERMIT HOLDERS ONLY |
| Accessible | DISABILITY, ACCESSIBLE, ACROD |
| EV Charging | EV CHARGING, ELECTRIC VEHICLE |

## Architecture

The app follows a pipeline architecture:

```
Camera -> OCR -> SignTextParser -> ParkingDecisionEngine -> UI
```

### Key Modules

- **Models/** - Shared data types (`ParkingRestriction`, `TimeWindow`, `ParkingDecision`, etc.)
- **Parser/** - `SignTextParser` and `TimeWindowParser` for converting OCR text to structured data
- **Engine/** - `ParkingDecisionEngine`, `RestrictionResolver`, and `ExplanationGenerator` for evaluating restrictions
- **Storage/** - `ScanHistoryStore` for persisting past scans
- **Database/** - SQLite schema for jurisdictions, sign types, and rules

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for a detailed module diagram and data flow description.

## Build Instructions

### Requirements

- Xcode 15.0 or later
- iOS 17.0+ deployment target
- Swift 5.9+
- A physical iOS device (camera features require real hardware)

### Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/your-org/CanIPark.git
   cd CanIPark
   ```

2. Open the project in Xcode:
   ```bash
   open CanIPark.xcodeproj
   ```

3. Select your development team under Signing & Capabilities.

4. Select a physical device as the run destination (the Simulator does not support camera capture).

5. Build and run (Cmd+R).

### Running Tests

```bash
xcodebuild test -scheme CanIPark -destination 'platform=iOS Simulator,name=iPhone 16'
```

Or use Cmd+U in Xcode.

## Project Structure

```
CanIPark/
  CanIPark/
    Models/          Data types and enums
    Parser/          OCR text parsing logic
    Engine/          Decision and resolution logic
    Storage/         Scan history persistence
    Database/        SQLite schema and seed data
    Info.plist       Privacy usage descriptions
  CanIParkTests/     Unit tests
  docs/              Documentation
```

See [docs/PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md) for a detailed file listing.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Data Model](docs/data_model.md)
- [Edge Cases](docs/edge_cases.md)
- [Failure Modes](docs/failure_modes.md)
- [Known Limitations](docs/KNOWN_LIMITATIONS.md)
- [Maintenance Playbook](docs/MAINTENANCE.md)
- [Legal Disclaimer](docs/LEGAL_DISCLAIMER.md)
- [Australian Parking Rules Research](docs/research/australian_parking_rules_research.md)

## Legal

This app is provided as a convenience tool only. It does not constitute legal advice. Always read the actual parking sign before making a parking decision. See [docs/LEGAL_DISCLAIMER.md](docs/LEGAL_DISCLAIMER.md) for full details.

## Author

**Kasunjith** — Main contributor and developer

## License

Copyright 2024-2026 Kasunjith. All rights reserved.
