# Failure Mode Matrix

This document catalogs each failure mode, its root cause, detection method, mitigation strategy, and user-facing message.

## Failure Mode Categories

| ID | Failure Mode | Cause | Detection | Mitigation | User Message |
|----|---|---|---|---|---|
| F01 | No text detected | Image contains no readable text (blank, too dark, too blurry) | OCR returns empty string | Show re-scan prompt | "No text could be read from this image. Try holding your phone closer to the sign in good lighting." |
| F02 | Unrecognised sign text | OCR text does not match any known parking sign pattern | Parser returns empty restriction array | Show uncertain verdict | "We could not identify a parking restriction from this sign. Please read the sign yourself." |
| F03 | Low OCR confidence | OCR produces text but with low internal confidence | Confidence score below 0.5 | Show low-confidence warning | "The sign text is unclear. The result may not be accurate. Please verify by reading the sign." |
| F04 | Partial text detection | Only part of the sign text was captured (cropped image) | Missing expected components (e.g., time window without category) | Reduce confidence, warn user | "Only part of the sign could be read. The result may be incomplete." |
| F05 | Multiple signs captured | Two or more unrelated signs in one photo | Multiple panels with conflicting categories at same time | Reduce confidence due to conflict | "Multiple signs were detected. Results apply to the most restrictive interpretation. Check each sign individually." |
| F06 | OCR character substitution | Common misreads: 0/O, 1/I/l, 5/S, 8/B | Preprocessing catches known patterns | OCR error correction in preprocessor | (Transparent to user - correction applied silently) |
| F07 | Non-standard sign format | Council-specific or temporary sign using unusual wording | Pattern match fails or matches wrong category | Return uncertain with low confidence | "This sign uses an unusual format. Please read the sign yourself to confirm." |
| F08 | Symbolic sign without text | Sign uses only colors and symbols (e.g., red circle, P icon) | No text extracted by OCR | Return empty result | "No readable text was found. This may be a symbolic sign. Please interpret the sign visually." |
| F09 | Wrong time zone | User is near a state border and device time zone does not match sign jurisdiction | Not detectable by app | Document in limitations | (Not detected at runtime) |
| F10 | Incorrect device clock | Device system time is wrong | Not detectable by app | Document in limitations | (Not detected at runtime) |

## Parsing Failure Modes

| ID | Failure Mode | Cause | Detection | Mitigation | User Message |
|----|---|---|---|---|---|
| F11 | Time range parse failure | Unusual time format (e.g., "8-6", "8 to 6") without AM/PM | `parseTimeRanges` returns empty | Return restriction without time windows (always active) | "Time restrictions could not be determined. The restriction may apply at all times." |
| F12 | Day range parse failure | Unusual day format (e.g., "weekdays", "M-F") | `parseDays` returns nil | Default to all days | "Day restrictions could not be determined. The restriction may apply every day." |
| F13 | Ambiguous duration | Text like "P" without a number | `parseTimedDuration` returns nil | Set maxStayMinutes to nil, reduce confidence | "A parking time limit is indicated but the duration could not be determined." |
| F14 | Conflicting durations | Text contains "2P" and "1 HOUR" in same panel | First match wins | Lower confidence due to internal conflict | "The sign appears to show conflicting time limits. Please check the sign." |
| F15 | Payment type ambiguity | Text mentions payment but format is unclear | Payment type set to `.unknown` | Payment status reported as `.unknown` | "Payment may be required. Check for meters or pay stations nearby." |

## Decision Engine Failure Modes

| ID | Failure Mode | Cause | Detection | Mitigation | User Message |
|----|---|---|---|---|---|
| F16 | No active restriction found | All restrictions have time windows, none match current time | Resolution result `isUnrestricted` is true | Return unrestricted decision with appropriate confidence | "No parking restrictions are currently active. You can park here freely." |
| F17 | Multiple active restrictions with same precedence | Two restrictions of same category active simultaneously | Multiple entries in `allActiveRestrictions` | First one wins (array order) | (Transparent - first restriction is used) |
| F18 | Restriction boundary ambiguity | Current time is within 5 minutes of window boundary | Boundary proximity check in resolver | Reduce confidence by 15% | "You are very close to a restriction time boundary. Rules may change soon." |
| F19 | Exempt vehicle type mismatch | User reports wrong vehicle type | Not detectable | Warn user to verify | "You appear to be exempt, but please verify the sign applies to your vehicle type." |
| F20 | Permit validity unknown | User claims to have permit but app cannot verify it | Not detectable | Accept flag but add warning | "Ensure your permit is clearly displayed on your vehicle." |

## Infrastructure Failure Modes

| ID | Failure Mode | Cause | Detection | Mitigation | User Message |
|----|---|---|---|---|---|
| F21 | Camera permission denied | User has not granted camera access | AVCaptureDevice authorization status check | Show settings prompt | "Camera access is required to scan parking signs. Please enable it in Settings." |
| F22 | Camera hardware failure | Device camera is malfunctioning | AVCaptureSession error callback | Show error state | "Unable to access the camera. Please try closing and reopening the app." |
| F23 | Location permission denied | User has not granted location access | CLLocationManager authorization status check | App works without location (no auto-holiday detection) | "Location access helps determine local rules but is not required." |
| F24 | Storage full | Device cannot save scan history | UserDefaults write failure caught | Silently drop oldest entries | (Transparent - old scans removed to make space) |
| F25 | JSON decode failure | Saved scan history is corrupted | JSONDecoder throws | Reset scan history | "Scan history could not be loaded and has been reset." |

## Severity Levels

| Severity | Description | Example |
|---|---|---|
| Critical | User may receive a parking fine if they rely on this result | F09 (wrong time zone), F10 (wrong clock) |
| High | Result is likely incorrect but user is warned | F03 (low confidence), F04 (partial text), F05 (multiple signs) |
| Medium | Result may be incomplete but core verdict is likely correct | F11 (no time range), F12 (no days), F15 (payment ambiguity) |
| Low | Minor inconvenience, no risk of incorrect decision | F24 (storage full), F25 (history corruption) |
| Informational | App works correctly but user needs to take action | F21 (camera permission), F23 (location permission) |

## Recovery Procedures

### For Critical Failures
1. Display a prominent warning that the result should not be relied upon
2. Encourage the user to read the physical sign
3. Log the failure for analytics (if user consents)

### For High-Severity Failures
1. Show the result with a reduced confidence indicator
2. Add a specific warning message explaining what went wrong
3. Offer a "re-scan" option

### For Medium-Severity Failures
1. Show the result with an informational note
2. Default to the most cautious interpretation

### For Low-Severity Failures
1. Handle silently
2. Log for debugging purposes

### For Informational Failures
1. Show a clear call-to-action for the user
2. Provide a direct link to the relevant Settings page if applicable
