# Plan — fixes from the 2026-11-05 code review

Scope: bug fixes and doc corrections only. No new user-facing behaviour except
honouring the device 12/24-hour setting. No intent/spec needed (fixes).

## Decisions (from user)
- Slots stay fixed (Stress / Calories / Body Battery / HR). Fix docs, drop dead code.
- Arc split threshold 240 is deliberate (single pass looked fine on device). Keep
  behaviour, rewrite the comment.
- Rename "Forerunner" → "Arches" everywhere (classes, files, README, comments).
  App ID unchanged, so store identity is unaffected.

## Changes, in order
1. `source/ArchesLogic.mc` (new) — pure helpers extracted from the view so they can
   be unit-tested: `slotReading(comp)`, `hourString(hour, is24Hour)`,
   `displayTemp(celsius, statute)`, `safeGetComplication(id)`.
   First extracted *verbatim* (bugs included), tests written, confirmed failing.
2. `test/ArchesLogicTest.mc` (new) — `(:test)` cases reproducing bugs 1, 3, 5.
   `monkey.jungle` sourcePath gains `test` (`(:test)` code is stripped from
   release builds).
3. Fix helpers:
   - null-safe `slotReading` (bug 1);
   - `safeGetComplication` wraps `getComplication` in try/catch (bug 2);
   - `hourString` honours 12h mode (12h keeps two digits, e.g. "05", because
     the bitmap layout is fixed at 4 digit slots) (bug 3);
   - `displayTemp` rounds after converting (bug 5).
4. View uses the helpers; arc-split comment rewritten (bug 4); removed unused
   `getCompMax` cases, `onComplicationChanged` and its registration (finding 6);
   date comment corrected.
5. Rename `ForerunnerWatchFace{App,View}` → `ArchesWatchFace{App,View}` (files +
   classes + manifest `entry`). README updated (name, slots, file table).

## Risks
- Riskiest: manifest `entry` rename — a mismatch fails at build, so caught by build.
- 12h mode changes what users with 12h setting see (intended).
- Removing the complication-change callback: face still redraws every minute.

## Proof
- Unit tests fail before step 3 for the expected reason, pass after.
- `monkeyc` build for fr965 succeeds; release export for all manifest devices.
- Simulator screenshot of the face (24h and 12h).

## Drift from plan (recorded during implementation)
- `ArchesLogic` also gained `slotValue(comp)` (shared by arcs and labels; removes
  the duplicated calorie override) and `compMax` replaces the view's `getCompMax`.
- README needed more than the rename: device list (was "fr965 only"), launcher icon
  size (65×65, not 40×40), the "replace placeholder UUID" step (now done; replaced
  with a never-change-the-ID warning), and a "Running the unit tests" section.
- `tools/gen_arc_icons.py` comment pointed at the old view filename; updated.
- Simulator check done in 12h mode only (the simulator's current setting);
  24h path is covered by `hourStringUnchangedIn24h`.

## Results
- Before fix: 8 tests, 2 pass / 6 error (null slot → "Failed invoking <symbol>"
  at `comp.getType()`; 12h and temperature assertions failed).
- After fix: 8/8 pass. fr965 build OK. Release export: 15/15 device builds OK.
- Simulator (fr965, 12h): 17:12 renders as 05:12; layout unchanged.

## Not covered by tests
- `safeGetComplication` exception path: no device in the manifest lacks one of the
  used types, so it can't be triggered in the simulator.
