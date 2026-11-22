# Plan: more devices + shorter date line

No intent/spec: this adds no new behaviour beyond device targets and a date-line
rule the user dictated in chat (2026-11-22). The plan records what changes and how
it is proven.

## Requests (2026-11-22, in order)

1. Add Venu 4 41mm (a user asked for it in a store message).
2. Hide the day of the week on the Venu 4 41mm, then also on the Venu 4 45mm.
3. In 12-hour mode the full date line (`SUN · NOV 22 · AM`) touches the arcs on the
   FR965, so all watches drop the day of the week when AM/PM is shown.
4. Add all remaining round AMOLED watches: 27 with installed profiles, plus the ones
   the user is installing via the SDK Manager (Venu 2 / 2 Plus / 2S, Approach S70 42mm,
   Approach S72 43/47mm, Descent Mk3 43mm, MARQ Gen 3, D2 Air X10).

## Files that change

- `manifest.xml`: product list, grouped by screen size.
- `monkey.jungle`:
  - `excludeAnnotations`: `compactDate` (no day of week, ever) for `venu441mm` and
    `venu445mm`. Every other watch uses `fullDate`.
  - Launcher icon `resourcePath` overrides for every device whose native size isn't 65.
- `resources-icon54/`, `resources-icon56/` (new): launcher icons from
  `tools/gen_launcher_icon.py`.
- `tools/gen_lowgfx_resources.py`, `resources-lowgfx-*/` (new; added during the build,
  see Drift).
- `source/ArchesLogic.mc`: `SHOW_DAY_OF_WEEK` (per-device, by annotation);
  `dateRowText` accepts a null day of week and drops it whenever `ampm` is set.
- `source/ArchesWatchFaceView.mc`: `drawDate` passes `null` when `SHOW_DAY_OF_WEEK`
  is false.
- `test/ArchesLogicTest.mc`: the 12-hour tests now expect `APR 27 · PM`, and there are
  tests for a null day of week.
- `README.md`: device list, date line rules, icon folders.

## Excluded on purpose

- **MIP watches** (fēnix 7/8 Solar, FR255/955, Enduro 3, Instinct 3 Solar/E): the face
  is designed for AMOLED. On MIP the dim low-power view is what users see almost all
  the time, and the gradient digit bitmaps would dither.
- **Instinct Crossover AMOLED**: its physical hands cover the face.
- **Venu X1**: rectangular screen.

## Risks

- **Small screens (360 and 390 px)**: fixed-size icons (weather, battery, arc metrics)
  are relatively larger, and the date line has less room. *Riskiest step.* Check
  visually on FR265S (360) and FR165 (390).
- **The 466 px screen (fēnix 9 Pro 51mm)**: scale > 1, so the digit bitmaps are
  upscaled slightly. Check visually.
- **Uninstalled profiles**: the store export fails if any manifest device is missing,
  so those devices are added only once their profiles are installed. Check their API
  level (≥ 4.2.0) and display type before adding.

## Proof

- Unit tests pass in the simulator.
- A screenshot for each screen size (360, 390, 416, 454, 466): nothing clipped, and
  the date line clears the arcs.
- `monkeyc -e -r` release export builds every manifest device.

## Drift from this plan

- **Watches without enhanced graphics.** FR165/165M, FR70, vívoactive 5 and Instinct 3
  AMOLED 45/50mm have `enhancedGraphicSupport: false`. They have no
  `Dc.drawScaledBitmap`, so the fallback drew the 120×180 digits and 48 px arc icons at
  full size, and soft alpha became on/off with a dither (jagged edges). Fix, with
  resources only and no code change: `tools/gen_lowgfx_resources.py` writes each digit
  and icon at exactly the size the view computes on that watch, blended onto black and
  opaque (every one is drawn over the black background), into `resources-lowgfx-<group>/`.
  `monkey.jungle` points those 6 watches at it. Icon sizes come from FONT_TINY/FONT_XTINY
  heights measured in the simulator (a throwaway test that was then deleted). If a
  firmware update changes those fonts, the icons are still drawn at the old size and
  only the gaps shift.
- The uninstalled watches were added in a second pass, once the user had installed every
  device down to API 5.0 in the SDK Manager. All 9 report API ≥ 5.0.0. That install also
  brought in the Approach S50 and Descent G2 (round AMOLED, 390 px, no enhanced graphics),
  which were added under the "all round AMOLED" decision and share
  `resources-lowgfx-approachs50` (both FONT_TINY 39 / FONT_XTINY 29). The Venu 2S needed
  a new 61 px launcher icon (`resources-icon61/`). Still excluded from that install:
  Venu Sq 2 / Sq 2 Music and Venu X1 (rectangular), Instinct Crossover AMOLED (hands).

## Results (2026-11-22, SDK 9.3.0)

- Unit tests: `Ran 49 tests — PASSED (passed=49, failed=0, errors=0)` (FR965, Venu 4 45mm, FR165).
- Release export: `46 OUT OF 46 DEVICES BUILT — BUILD SUCCESSFUL` (39 products).
- Screenshots (simulator, 12-hour mode): FR265S 360, FR165 / vívoactive 5 / Instinct 3
  AMOLED 45mm / Venu 4 41mm 390, FR265 / Instinct 3 AMOLED 50mm 416, FR965 / Venu 4 45mm
  454, fēnix 9 Pro 51mm 466. Nothing clipped; the date line clears the arcs.
- Not seen: 24-hour mode on screen (covered by `dateRowText24h`), and real hardware.

### Second pass (11 more watches; 50 products)

- Release export: `64 OUT OF 64 DEVICES BUILT — BUILD SUCCESSFUL`.
- Unit tests on Approach S50: `Ran 49 tests — PASSED (passed=49, failed=0, errors=0)`.
- `drawScaledBitmap` present on all new watches except Approach S50 and Descent G2
  (checked in each `*.api.debug.xml`).
- Screenshots: Approach S50, Descent G2 (390, low graphics), Venu 2S (360), Venu 2 (416),
  MARQ Gen 3 (454). Nothing clipped, edges smooth, date line clear of the arcs.
