# Spec — polish after review (items 1, 2, 4, 5)

Intent: `intent.md` (same folder). Decisions from user on 2026-11-05: AM/PM in the date
row; night from real sunrise/sunset with fixed-hours fallback.

## Areas of concern (up front)
- **Permissions (risky assumption):** sunrise/sunset needs a `Position.Location`. We use
  the one the weather data already carries (`CurrentConditions.observationLocationPosition`),
  not GPS. Assumed not to need the `Positioning` permission; verified by build and
  simulator run. If it does need it, fall back to fixed hours rather than adding a
  permission (adding one shows a new prompt to every user).
- **Font coverage:** the date row uses "·" (U+00B7). If the system font lacks it on a
  device it renders as a box. Verified in the simulator on fr965 only.
- **Always-on burn-in:** AM/PM adds a few lit pixels in AOD. Kept dim (same 0x555555
  as the time), small (XTINY), and drifts with the time.
- **Stale data:** sunrise/sunset recomputed at most once per hour; a location change
  takes up to an hour to show. Acceptable.
- **Launcher icon 65×65 unchanged:** only the 60 and 70 sizes are new, so the existing
  store icon on the other 7 devices doesn't change.

## Requirements
- R1 Digit bitmaps reload only when the displayed hour/minute string changes; metric
  icons and colon load once; the weather icon reloads only when it changes.
- R2 `is24Hour == false` → date row reads `<MON> <D> · AM|PM`; 00:00–11:59 = AM,
  12:00–23:59 = PM. Always-on mode shows AM/PM under the time in the same dim colour.
  `is24Hour == true` → unchanged.
- R3 Conditions in the "sun" group (clear, fair, mostly clear, partly clear, thin
  clouds) show `WeatherMoon` at night, `WeatherSun` by day. All other groups unchanged.
- R4 Night = now < sunrise or now ≥ sunset. If sunrise or sunset is unavailable:
  local hour < 6 or ≥ 20.
- R5 Launcher icon is native size per device: 60×60 for epix2pro51mm and
  descentmk351mm, 70×70 for venu3 and approachs7047mm, 65×65 elsewhere. No
  "launcher icon isn't compatible" build warnings.

## Design
- `ArchesLogic`: add `ampmLabel(hour)`, `isNight(now, sunrise, sunset, hour)` (seconds
  since epoch or null), `weatherIconFor(condition, night)` (moves the condition map out
  of the view).
- View: bitmap cache fields; `_nightCache` recomputed hourly via `Weather` API.
- Assets: `tools/gen_moon_icon.py` → `weather_moon.png` (32×32, pale yellow, same flat
  style as the sun). `tools/gen_launcher_icon.py` → `launcher_icon_60.png`,
  `launcher_icon_70.png`, wired via `resources-icon60/`, `resources-icon70/` and
  per-device `resourcePath` lines in `monkey.jungle`.
