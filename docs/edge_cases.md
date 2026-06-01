# Edge Cases

A comprehensive catalog of edge cases organized by category. Each entry describes the scenario, expected behavior, and any caveats.

## Time-Related Edge Cases

### 1. Midnight boundary
**Scenario**: A restriction ends at midnight (e.g., "6PM-12AM").
**Expected**: The restriction is active up to 23:59. After midnight, the next day's rules apply.
**Caveat**: `TimeOfDay` midnight is `(0, 0)` which sorts before all other times.

### 2. Time window exactly at boundary
**Scenario**: The current time is exactly the start or end of a time window (e.g., 8:00 AM for an "8AM-6PM" window).
**Expected**: The window uses `>=` for start and `<=` for end, so both boundary times are included.

### 3. One minute before window starts
**Scenario**: Current time is 7:59 AM for an "8AM-6PM" restriction.
**Expected**: The restriction is not yet active. Parking is unrestricted (or subject to other signs).

### 4. One minute after window ends
**Scenario**: Current time is 6:01 PM for an "8AM-6PM" restriction.
**Expected**: The restriction has ended. Parking is unrestricted.

### 5. Time window spanning noon
**Scenario**: "10AM-2PM" restriction.
**Expected**: Correctly handled. The 12-hour to 24-hour conversion handles noon (12 PM = hour 12) correctly.

### 6. Very short time window
**Scenario**: "8AM-8:15AM" restriction.
**Expected**: Window is only 15 minutes. The near-end-of-window warning may fire immediately.

### 7. Near-end-of-window with timed parking
**Scenario**: "2P 8AM-6PM" and it is currently 5:50 PM (10 minutes left in window).
**Expected**: The app warns that the parking window ends in 10 minutes and the user may not have enough time for the full 2-hour stay.

### 8. Device clock is wrong
**Scenario**: Device clock is set to the wrong time or time zone.
**Expected**: Decisions will be based on the incorrect time. No mitigation is possible within the app.

### 9. Daylight saving transition
**Scenario**: Sign says "2P 8AM-6PM" and the clocks change at 2 AM.
**Expected**: The app uses the device's system time, which automatically adjusts. During the "spring forward" hour, 2:00-3:00 AM does not exist. During "fall back", 2:00-3:00 AM occurs twice. Parking signs at these hours may produce ambiguous results.

### 10. Multiple time ranges on one sign
**Scenario**: "NO STOPPING 7AM-9AM 4PM-6PM MON-FRI"
**Expected**: Two separate time windows are created. The restriction is active during either window.

## Day-Related Edge Cases

### 11. Weekend-only restriction
**Scenario**: "2P 8AM-6PM SAT-SUN"
**Expected**: Restriction only applies on Saturday and Sunday. Weekdays are unrestricted.

### 12. Single day restriction
**Scenario**: "NO STOPPING 7AM-9AM FRI"
**Expected**: Only applies on Friday mornings.

### 13. Day range wrapping around the week
**Scenario**: "SAT-TUE" (Saturday through Tuesday).
**Expected**: Includes Saturday, Sunday, Monday, Tuesday.

### 14. Full week specification
**Scenario**: "MON-SUN"
**Expected**: All seven days. Same as omitting the day specification.

### 15. Inconsistent day abbreviations
**Scenario**: "TUES-THURS" vs "TUE-THU" vs "TUESDAY-THURSDAY"
**Expected**: All forms resolve to Tuesday, Wednesday, Thursday. The parser normalises to three-letter abbreviations.

## Public Holiday Edge Cases

### 16. Public holiday on a weekday
**Scenario**: Christmas Day falls on a Wednesday. Sign says "2P 8AM-6PM MON-FRI EXCEPT PUBLIC HOLIDAYS".
**Expected**: On Christmas Day, the restriction does not apply even though it is a Wednesday.

### 17. Public holiday on a weekend
**Scenario**: Australia Day falls on a Saturday. Sign says "NO PARKING MON-FRI EXCEPT PUBLIC HOLIDAYS".
**Expected**: Saturday is already outside the day range, so the restriction does not apply regardless of the holiday flag.

### 18. Substitute public holiday
**Scenario**: New Year's Day falls on a Saturday, so Monday is declared a substitute public holiday.
**Expected**: The app relies on the `isPublicHoliday` flag being correctly set for the substitute day.

### 19. Public holiday only restriction
**Scenario**: "NO PARKING 8AM-6PM PUBLIC HOLIDAYS ONLY"
**Expected**: This restriction only activates on public holidays.

### 20. No public holiday specification
**Scenario**: Sign has no mention of public holidays.
**Expected**: `publicHolidayBehavior` is `.unspecified`. The restriction applies regardless of holiday status.

## School Day Edge Cases

### 21. School days during school holidays
**Scenario**: Sign says "NO STOPPING 8AM-9AM SCHOOL DAYS" and it is a weekday during school holidays.
**Expected**: `isSchoolDay` is false during holidays, so the restriction does not apply.

### 22. School days on weekends
**Scenario**: Sign says "SCHOOL DAYS" and it is Saturday.
**Expected**: `isSchoolDay` should be false on weekends, so the restriction does not apply.

### 23. School days and public holidays overlap
**Scenario**: A public holiday falls during school term.
**Expected**: `isSchoolDay` should be false on public holidays (schools are closed). The `isSchoolDay` and `isPublicHoliday` flags are independent; both should be set correctly.

### 24. Pupil-free days
**Scenario**: A school has a pupil-free day during term.
**Expected**: These are not detectable by the app. The `isSchoolDay` flag should ideally be false, but this depends on the data source.

## Sign Text Edge Cases

### 25. OCR reads zero as O
**Scenario**: OCR produces "N0 ST0PPING" instead of "NO STOPPING".
**Expected**: The preprocessor corrects common OCR substitutions.

### 26. OCR reads lowercase L as uppercase I
**Scenario**: OCR produces "PARKlNG" instead of "PARKING".
**Expected**: The preprocessor corrects this.

### 27. En-dash vs hyphen vs em-dash
**Scenario**: Time range uses en-dash "8AM– 6PM" or em-dash "8AM—6PM" instead of hyphen.
**Expected**: The preprocessor normalises all dash types to ASCII hyphen.

### 28. Extra whitespace
**Scenario**: "2P   METER   8AM  -  6PM"
**Expected**: Regex patterns use `\s+` and `\s*` to handle variable whitespace.

### 29. Mixed case
**Scenario**: "No Stopping 8am-6pm Mon-Fri"
**Expected**: Text is uppercased before pattern matching.

### 30. Trailing/leading whitespace
**Scenario**: "  2P METER  "
**Expected**: Text is trimmed during preprocessing.

### 31. Empty string
**Scenario**: OCR returns an empty string.
**Expected**: Parser returns an empty array. Engine treats this as unrestricted with low confidence.

### 32. Very long text
**Scenario**: OCR returns an extremely long string (e.g., multiple signs captured).
**Expected**: The panel splitter divides the text. Each panel is parsed independently.

## Category Detection Edge Cases

### 33. "P" alone without a number
**Scenario**: Sign just says "P".
**Expected**: Detected as `.timedParking` with no max stay and low confidence (0.70).

### 34. Loading zone with timed duration
**Scenario**: "LOADING ZONE 30 MIN"
**Expected**: Category is `.loadingZone`, maxStayMinutes is 30.

### 35. Loading zone without timed duration
**Scenario**: "LOADING ZONE"
**Expected**: Category is `.loadingZone`, maxStayMinutes is nil.

### 36. Permit zone vs permit holders excepted
**Scenario**: "PERMIT ZONE" vs "NO PARKING PERMIT HOLDERS EXCEPTED"
**Expected**: First is `.permitZone`. Second is `.noParking` with `.permitHolders` exemption.

### 37. Disability parking with time limit
**Scenario**: "DISABILITY 2P"
**Expected**: Category is `.accessible`, maxStayMinutes is 120.

### 38. Multiple categories in one panel
**Scenario**: "NO STOPPING LOADING ZONE"
**Expected**: `NO STOPPING` has higher precedence and is matched first.

## Payment Edge Cases

### 39. Metered parking outside paid hours
**Scenario**: "2P METER 8AM-6PM" and it is 7 PM.
**Expected**: Outside hours, parking is unrestricted and free. The meter payment requirement is part of the time-windowed restriction.

### 40. Pay and display variant
**Scenario**: "PAY & DISPLAY" vs "PAY AND DISPLAY"
**Expected**: The regex matches `PAY\s+&?\s*DISPLAY`, covering both forms.

### 41. No payment indicator on timed parking
**Scenario**: "2P 8AM-6PM"
**Expected**: Payment type is `.none`, payment status is `.free`.

## Exemption Edge Cases

### 42. Bus exempt from no stopping
**Scenario**: "NO STOPPING EXCEPT BUSES" and the vehicle is a bus.
**Expected**: Bus is exempt; decision is `.yes`.

### 43. Car not exempt from bus exemption
**Scenario**: "NO STOPPING EXCEPT BUSES" and the vehicle is a car.
**Expected**: Car is not exempt; decision is `.no`.

### 44. Multiple exemptions
**Scenario**: "NO STOPPING EXCEPT BUSES EXCEPT TAXIS"
**Expected**: Both `.buses` and `.taxis` should be in the exemptions list.

### 45. Permit holder exemption with timed parking
**Scenario**: "2P WITH PERMIT" and the user has a permit.
**Expected**: The permit holder exemption is detected. If `hasPermit` is true and the exemption is `.permitHolders`, the engine grants an exempt decision.

### 46. Disability exemption on non-accessible sign
**Scenario**: "NO PARKING DISABLED"
**Expected**: The `.disabilityPermit` exemption is detected due to the word "DISABLED".

## Arrow Direction Edge Cases

### 47. Left arrow text
**Scenario**: Sign contains "<--" or the word "LEFT".
**Expected**: `arrowDirection` is `.left`.

### 48. Right arrow text
**Scenario**: Sign contains "-->" or the word "RIGHT".
**Expected**: `arrowDirection` is `.right`.

### 49. Both arrows
**Scenario**: Sign contains "<-->" or both "LEFT" and "RIGHT".
**Expected**: `arrowDirection` is `.both`.

### 50. Unicode arrows
**Scenario**: Sign text contains "←" (left arrow) or "→" (right arrow).
**Expected**: Detected by the arrow regex patterns.

## Multi-Panel Edge Cases

### 51. Two panels with different restrictions
**Scenario**: "2P 8AM-6PM MON-FRI\n\n1P 8AM-12PM SAT"
**Expected**: Two separate restrictions are parsed. On a Saturday at 10 AM, the 1P restriction is active.

### 52. Panel separator with dashes
**Scenario**: Text separated by "---" or "==="
**Expected**: The panel splitter recognises these as separators.

### 53. Single panel with no separator
**Scenario**: "2P 8AM-6PM MON-FRI"
**Expected**: One restriction is parsed.

### 54. Three or more panels
**Scenario**: "NO STOPPING 7-9AM\n\n2P 9AM-6PM\n\n1P 6PM-10PM"
**Expected**: Three restrictions are parsed and evaluated by precedence.

## Confidence Edge Cases

### 55. Very short OCR text
**Scenario**: Only "2P" is detected (2 characters of alphanumeric content).
**Expected**: Confidence is reduced by the short-text penalty (multiplied by 0.7).

### 56. Low alphanumeric ratio
**Scenario**: OCR returns mostly symbols and punctuation with little readable text.
**Expected**: Confidence is reduced by the low-ratio penalty (multiplied by 0.8).

### 57. Multiple conflicting active restrictions
**Scenario**: Two restrictions of different categories are both active.
**Expected**: Resolution confidence is reduced by 10% due to the conflict.

### 58. Near boundary of time window
**Scenario**: Current time is within 5 minutes of the window end.
**Expected**: Resolution confidence is reduced by 15% due to boundary proximity.
