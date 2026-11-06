# Plan: battery next to weather, touch-and-hold to open arcs

Spec: `spec.md` (signed off 2026-11-06, with hold-to-open replacing tap).
Branch: `feature/battery-tap-to-open`.

## Order

1. **Tests first** (`test/ArchesLogicTest.mc`), per spec "Verification":
   `batteryPercent`, `batteryText`, `isBatteryLow`, `slotAt`. Build and run them, and
   confirm they fail because the symbols are undefined.
2. **`source/ArchesLogic.mc`**: implement the four helpers (spec "Design"). Tests pass.
3. **Icons**: `tools/gen_battery_icons.py` (Pillow, 8× supersampled like
   `gen_moon_icon.py`) → `resources/images/battery.png`, `battery_low.png`,
   `battery_charging.png` (32×32). Register them in
   `resources/drawables/drawables.xml` as `IconBattery`, `IconBatteryLow` and
   `IconBatteryCharging`.
   - Battery: a horizontal outline (body + terminal nub) with a solid inner fill
     bar. It's a static icon; the fill level doesn't move.
   - Charging: a lightning bolt polygon.
4. **`source/ArchesWatchFaceView.mc`**
   - Rename `drawWeather` → `drawInfoRow`. Read `System.getSystemStats()` once per
     frame. Build the parts (weather icon?, temp?, ` · `, battery/charging icon,
     pct), measure the total width, centre it and draw it. Colors follow B4–B6.
     Battery bitmaps are cached, keyed by resource id like `_weatherBmp`.
   - Record `_hitExclusions` (time block, date row, info row rects) in `drawTime`,
     `drawDate` and `drawInfoRow` from the values they already compute.
   - Add public `slotAtPoint(x, y)` → `ArchesLogic.slotAt(...)`, `compIdForSlot(i)`,
     and `isLowPower()`.
5. **`source/ArchesWatchFaceDelegate.mc`** (new): `onPress(evt)` implements T3.
   `evt.getCoordinates()` → slot → `safeGetComplication` non-null → `exitTo`,
   wrapped in `try/catch` → `true`. Everything else → `false`.
   **`source/ArchesWatchFaceApp.mc`**: `getInitialView()` returns
   `[view, new ArchesWatchFaceDelegate(view)]`.
6. **README**: features (battery, hold-to-open), layout list (new files/icons/tool),
   architecture table (`drawInfoRow`, delegate).
7. **Verify** (see Proof), then record the results and any drift below.

## What could break
- **The weather row layout**: the row is rebuilt from scratch, so the old
  "no temperature → hide row" path changes on purpose (B2). A regression here
  would misplace the weather icon or temperature that already ships.
- **Hold behaviour users already rely on**: if `onPress` returns `true` too often
  (e.g. a bug in the exclusions), holding the face no longer opens the
  system's watch-face menu, except from dead centre.
- **Memory**: three more 32×32 bitmaps (~4 KB each when loaded) plus the
  delegate. The last measured peak was 18.3 of 123.9 kB, so there's ample headroom.
- **Store build**: a new source file and resources have to build for all 11
  products. The release export catches this.

## Riskiest step
Step 5, hold-to-open. It can't be fully proven off-device: the simulator may not
launch native apps through `exitTo`, and whether calories has a target can only be
seen on the watch. Mitigations: `exitTo` is wrapped and failures return `false`; the
pure hit-testing is unit-tested; and on the simulator I log the slot and return
value for each quadrant, then remove the logging before committing.

## Rejected alternatives
- **Plain tap (`onTap`)**: config mode only (API 5.1), so it doesn't fire on a
  live face.
- **Drawing the battery with `dc` primitives** (a live fill level): no ⚡ glyph
  is guaranteed, the result looks inconsistent next to the bitmap weather icons, and
  it adds per-frame draw calls. PNGs match the existing convention.
- **Ring-only hit area**: rejected by the user (answer 5). A 24 px target is too
  small for a held touch.
- **Red while charging at ≤ 15%**: reads as an alarm while the problem is already
  being fixed (spec B5, my call).
- **Battery in its own row or arc gap**: the user asked for it next to weather.

## Proof
- Unit tests: the new ones fail first, then pass; existing 28 still pass. The
  test runner output is pasted below.
- `monkeyc` release export (`-e -r`) for all 11 products: success, with no new
  warnings.
- Simulator fr965 screenshots: battery 78% (gray), 10% (red), charging (⚡ gray),
  weather off (battery only). Compared against the spec examples.
- Simulator hold on each quadrant, the time and the date: logged slot and return
  value.
- On device (user): hold each arc → its native view opens, or for an unsupported
  type nothing happens.

## Drift from plan (recorded during implementation)
- Baseline is 28 tests, not 15 (the earlier figure was from the previous change).
- Implemented by a planner/worker/reviewer agent team; task split in
  `.agent-runs/battery-tap-to-open/plan.json` (T1 tests, T2 logic, T3 icons, T4 view,
  T5 delegate+app, T6 README).
- Review round 1: accept (0 blocker/major). Fixed the minor + 2 nits in place: README
  drawable count 59→60 (was already off by one before this change), ArchesLogic
  description, delegate class comment.
- Battery 10% / charging / weather-off states were not screenshotted: the simulator's
  battery controls weren't driven. Covered by unit tests (isBatteryLow) and code review only.

## Results
- Tests: the new tests failed first (test build: undefined symbols batteryPercent,
  batteryText, isBatteryLow, slotAt). Now `Ran 47 tests / PASSED (passed=47, failed=0,
  errors=0)` (28 existing + 19 new).
- Release export (`-e -r -w`): BUILDING FOR 15 DEVICES → BUILD SUCCESSFUL, no warnings.
- Simulator fr965: row under the time renders `☁ 14° · ▭ 50%`, clear of the arcs.
  Peak memory 18.3 → 20.9 kB (of 123.9 kB).
- Simulator holds (temporary logging, since removed): time, date, info row → slot null,
  returns false. Each arc → its slot, then `exitTo`. The simulator showed "Heart Rate
  launched", "Stress launched", "Calories launched" and "Body Battery launched".
- NOT verified: red (≤15%) and ⚡ (charging) rendering, the weather-off row, venu3 visuals,
  and real launches on a device.
