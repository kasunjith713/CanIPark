# Known Limitations

## OCR Accuracy

1. **Low-light conditions**: OCR accuracy drops significantly in poor lighting. Signs photographed at night or in shadow may produce unreliable results.

2. **Damaged or faded signs**: Signs with peeling paint, graffiti, stickers, or sun-faded text may not be readable.

3. **Non-standard fonts**: Some council-specific signs use non-standard fonts or layouts that the OCR engine may not recognise correctly.

4. **Angled or distant photos**: Best results require the sign to be roughly front-on and occupy a significant portion of the frame.

5. **Multiple signs in one frame**: The app processes all detected text as one block. Capturing two unrelated signs in the same photo may produce incorrect results.

6. **Reflections and glare**: Reflective sign surfaces under direct sunlight or artificial light may wash out portions of the text.

## Parsing Limitations

7. **Symbolic signs**: The parser operates on text only. Signs that use icons, pictograms, or color-coded backgrounds without text cannot be interpreted (e.g., a red circle with no text).

8. **Arrow interpretation**: Left/right arrows are detected but the app cannot determine whether you are standing on the correct side of the sign.

9. **Stacked sign priority**: When multiple physical signs are stacked on one pole, the app cannot determine their spatial relationship or which one is "on top" (and therefore takes precedence).

10. **Non-English signs**: Only English-language Australian parking signs are supported.

11. **Handwritten additions**: Temporary handwritten or printed additions to signs (e.g., "SUSPENDED") are not reliably detected.

12. **Complex conditional signs**: Signs with multiple overlapping conditions (e.g., "2P 8AM-6PM MON-FRI, 1P 8AM-12PM SAT, 4P OTHER TIMES") may not be fully decomposed if the panel separation is unclear.

## Time and Date Limitations

13. **Device clock accuracy**: All decisions depend on the device's system clock. An incorrectly set clock will produce wrong results.

14. **Time zone handling**: The app uses the device's current time zone. If the device time zone does not match the sign's jurisdiction (e.g., travelling near state borders), results may be incorrect.

15. **Public holidays**: The app relies on the caller to specify whether the current day is a public holiday. It does not maintain its own public holiday calendar. State-specific, council-specific, and observed/substitute holidays are not automatically detected.

16. **School day detection**: Similar to public holidays, the app relies on external input for school day status. School term dates vary by state and school type and are not built in.

17. **Daylight saving transitions**: On daylight saving changeover days, time window calculations may be slightly off during the transition hour.

## Decision Logic Limitations

18. **No parking vs. No stopping nuance**: The app explains the legal difference but cannot determine whether you are performing a permitted activity (e.g., dropping off passengers in a No Parking zone).

19. **Loading zone eligibility**: The app cannot determine whether you are actually loading or unloading goods.

20. **Permit validation**: The app can accept a "has permit" flag but cannot verify the permit's validity, type, or area applicability.

21. **Vehicle type self-reporting**: Exemptions based on vehicle type rely on the user accurately identifying their vehicle type.

22. **Maximum stay tracking**: The app calculates how long you can stay from "right now" but does not track how long you have already been parked.

23. **Clearway tow risk**: The app warns about towing during clearway hours but cannot determine how quickly enforcement operates in practice.

## Coverage Limitations

24. **State variations**: Australian parking rules are largely standardised but some state-specific variations exist (e.g., definitions of "stop" vs. "park" in different road rules acts). The app follows the most common interpretation.

25. **Private property**: The app only covers public road parking signs. Private car park signs, shopping centre rules, and body corporate restrictions are not supported.

26. **Construction zones**: Temporary signs for road works, events, or construction are not covered.

27. **Metered parking rates**: The app detects that payment is required but does not provide rate information.

28. **Time-limited free parking in paid zones**: Some metered zones allow a short free period. This is not detected.

29. **Council-specific rules**: Some councils have additional rules (e.g., resident parking schemes, time-limited free parking areas) that are not captured by sign text alone.

30. **Multi-sign interactions**: When two signs on separate poles interact (e.g., a "2P" sign and a separate "NO STOPPING 4-6PM" sign), the app cannot combine them unless both are captured in a single scan.
