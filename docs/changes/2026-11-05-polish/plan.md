# Plan — polish after review (items 1, 2, 4, 5)

Spec: `spec.md`. Branch: `feature/arches-review-fixes` (same PR).

## Order
1. Tests first (`test/ArchesLogicTest.mc`): `ampmLabel`, `isNight`, `weatherIconFor`.
   Confirm they fail (undefined symbols).
2. `source/ArchesLogic.mc`: implement the three helpers; tests pass.
3. `tools/gen_moon_icon.py` → `resources/images/weather_moon.png`; register
   `WeatherMoon` in `resources/drawables/drawables.xml`.
4. `source/ArchesWatchFaceView.mc`: bitmap caching (R1), AM/PM in date row and AOD
   (R2), night lookup + `weatherIconFor` (R3, R4); remove the old `readWeatherIcon` map.
5. `tools/gen_launcher_icon.py` → 60/70 icons; first check that its 65 output matches
   the current icon closely, to prove the geometry is right. `resources-icon60/`,
   `resources-icon70/`, `monkey.jungle` per-device paths (R5).
6. README: features list, project layout, tools.

## Risks
- Riskiest: step 4 caching — a stale cache would show the wrong time. Mitigated by
  keying the digit cache on the exact hour+minute strings.
- Jungle per-device resource paths: a typo silently uses the default icon. Proof is
  the absence of launcher-icon warnings in the export.
- `Weather.getSunrise` permission (see spec concerns).

## Rejected alternatives
- AM/PM next to the time: needs shrinking the digits on a round screen.
- Fixed night hours only: wrong across seasons/latitudes.
- Upscaling/downscaling the existing PNG: same blur the change is meant to remove.

## Drift from plan (recorded during implementation)
- One new test (`weatherIconOtherConditionsIgnoreNight`) first errored because
  `Test.assertEqual(x, null)` calls `.equals` on null. The test was wrong, not the
  code; rewritten as `Test.assert(x == null)`, which checks the same thing.
- The generator's 65 px output was compared to the original icon: mean pixel
  difference about 2–3% (slightly crisper edges, marginally larger corner radius).
  The original 65 px file is kept as-is.

## Results
- New tests failed first (undefined symbols); now 15/15 pass.
- Release export 15/15 device builds; launcher-icon warnings: 0 (were 4 devices).
- Simulator fr965, 12h: date row "NOV 5 · PM"; digits refresh on minute change
  (05:31 → 05:32). Peak memory 13.9 kB → 18.3 kB (of 123.9 kB) from caching.
- NOT verified visually: always-on mode AM/PM, and the moon (simulator weather was
  cloudy). Both are covered by unit tests for the logic only. Sunrise/sunset
  lookup without the Positioning permission: no error in the simulator, not tried on
  a device.

## Proof
- Unit tests pass (old 8 + new).
- Release export 15/15 with no launcher-icon warnings.
- Simulator screenshots: 12h (AM/PM in date row), always-on mode, night moon
  (simulator time set to night, clear weather).
