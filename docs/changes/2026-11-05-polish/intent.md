# Intent — polish after review (items 1, 2, 4, 5)

## Problem
1. After a wrist raise the face redraws every second and reloads 9 bitmaps each time.
2. In 12-hour mode the time shows "05:12" with no way to tell AM from PM.
4. A clear night shows a sun icon.
5. The 65×65 launcher icon is rescaled (blurry) on devices that want 60×60 or 70×70.

## Proposed outcome
1. Bitmaps load once (icons) or only when the minute changes (digits).
2. 12-hour mode shows AM/PM in the date row ("NOV 5 · PM"), and under the time in
   always-on mode. 24-hour mode unchanged.
4. Clear-sky conditions at night show a crescent moon. Night = before sunrise or after
   sunset at the weather location; fallback 20:00–06:00 when that's unavailable.
5. Native 60×60 and 70×70 launcher icons for the devices that need them.

## Affected users and systems
All users of the face on the 11 manifest devices. Store listing icon on 4 devices.

## Constraints
- AMOLED burn-in rules for always-on mode (dim, few lit pixels, drift).
- No new permissions unless unavoidable.
- Layout is resolution-independent; nothing may be hard-coded to 454 px.

## Open questions
- Does `Weather.getSunrise` with the conditions' location work without the
  Positioning permission? (Answered in spec: verify in build + simulator.)
