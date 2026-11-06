# Intent — battery next to weather, tap-to-open arcs

First of two changes from the 2026-11-06 feature review. Configurable arcs come
next as their own change. Status icons (phone, notifications, alarm, DND) are out
of scope for now.

## Problem
1. The face doesn't show the watch's battery level anywhere, and that's the
   number people check most on a watch face.
2. The four arcs show heart rate, stress, body battery and calories, but you
   can't get from an arc to the detail behind it. To see your stress history you
   have to leave the face and look for the widget yourself.

## Proposed outcome
1. **Battery next to weather, with a dot separator.** The row under the time
   reads `<weather icon> <temp>° · <battery>%`, e.g. `⛅ 18° · 78%`.
   - If weather is unavailable, the row shows only the battery: `78%`.
   - The battery figure and separator use the same light gray as the temperature.
   - Always-on (low power) mode doesn't change.
2. **Tap-to-open.** On a touchscreen, tapping one of the four arcs (or its
   icon and value) opens that metric's native Garmin view: heart rate, stress,
   body battery, calories.
   - Tapping the time, date or weather row does nothing.
   - Buttons and watches without touch behave as they do today.

## Affected users and systems
- Everyone using the face on the 11 manifest devices (all touchscreen, 454×454
  round AMOLED).
- Code: `ArchesWatchFaceView.mc` (weather row), `ArchesLogic.mc` (pure text and
  hit-test helpers + tests), `ArchesWatchFaceApp.mc` (returns a
  `WatchFaceDelegate`), plus a new delegate class. README needs updating.

## Constraints
- No new permissions. Battery comes from `System.getSystemStats().battery`, and
  launching uses the existing `ComplicationSubscriber` (`Complications.exitTo`).
- `minApiLevel` stays at 4.2.0.
- The layout stays resolution-independent: nothing hard-coded to 454 px.
- The wider weather row must stay clear of the bottom arcs and the bottom arc
  labels. At 454 px, `⛅ 18° · 78%` is about 150 px wide, and the space between
  the arcs at that height is about 250 px.
- AMOLED burn-in: the battery adds a few static lit pixels in active mode only,
  the same as the temperature does today.
- Pure logic (battery text, row text, which arc a tap hits) goes in
  `ArchesLogic` and gets unit tests.

## Open questions (answered 2026-11-06)
1. **Low-battery color:** turn red (at ≤ 15%).
2. **Charging:** use a battery icon normally, and replace it with ⚡ while charging.
3. **Rounding:** round.
4. **Calories / no launch target:** do nothing if not available.
5. **Hit area:** the whole area, i.e. the arc's quadrant including its icon and value.

Carried into the spec: the SDK only delivers **touch-and-hold** to a watch face
(`WatchFaceDelegate.onPress`). A plain tap (`onTap`) is reserved for watch-face
config mode. See spec, "Areas of concern".
