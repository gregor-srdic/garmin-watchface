# Plan: visual refresh toward `assets/design.png`

Machine plan: `.agent-runs/visual-refresh/plan.json`. There is no intent.md or spec.md for
this change. The nine requirements came from the user in the orchestration brief.

## Requirements (short)
1. Active mode uses full-saturation accents (0xffa040, 0xff7da3, 0x4a9eff, 0xff4d4d). Always-on stays as it is today.
2. Metric value in FONT_TINY and the accent color, with an uppercase caption in FONT_XTINY dim gray
   (BPM/STRESS/BODY/KCAL from strings.xml) and a small icon next to the caption.
3. One row below the time: `MON · APR 27 [· PM] · ☀ 58°`. If there is no weather, it shows only the date. The time+row block is centred vertically.
4. ~~DROPPED by user 2026-11-05 (see Drift)~~ Arcs about 67% as thick (16·scale), plus a thin 0x1a1a1a outer ring (active only). All four ticks are placed the same way relative to the ring/band.
5. Continuous pink→purple→blue gradient across the HH:MM digit PNGs, made by a new generator.
6. A zero or no-data arc draws a dot at its start in the accent color.
7. ~~DROPPED by user 2026-11-05 (see Drift)~~ Neutral track color 0x1a1a1a.
8. ~~DROPPED by user 2026-11-05 (see Drift)~~ Symmetric gaps around the 12/3/6/9 ticks.
9. Temperature in light gray 0xcccccc. The weather icon keeps its own colors.

## Files and order
| Task | Files | Depends on |
|---|---|---|
| T1 Pure helpers + tests | `source/ArchesLogic.mc`, `test/ArchesLogicTest.mc` | none |
| T2 Asset regeneration | `tools/gen_arc_icons.py`, new `tools/gen_digit_gradient.py`, `resources/images/{hr,stress,body,calories}.png`, the 41 digit PNGs, `resources/drawables/drawables.xml` (comment only) | none |
| T3 View rendering | `source/ArchesWatchFaceView.mc`, `resources/strings/strings.xml` | T1, T2 |
| T4 Docs | `README.md`, this file (Drift/Results) | T1–T3 |

T1 and T2 run in parallel. T3 waits for T1 because monkeyc compiles `source;test` together, so a parallel
build would see the other task's half-finished edits.

New ArchesLogic API (T1): `ROW_SEP`, `dateRowText(dow, month, day, ampm?)`, `tempText(temp?)`,
`arcFillEnd(startD, endD, value, maxV)`.

Digit gradient geometry: slot widths 72,72,39,72,72 with a 2 px kern (total 335) at the 454 reference. These
match `drawTime()`. T3 must not change `dwFull`, `dwColon` or `kern`.

## Risks
- **Riskiest: label fit (T3).** FONT_TINY values plus captions have to fit between the time block and the
  inner edge of the arc band on a round screen. Font heights differ per device. Proof: screenshots on fr965 and venu3.
- **Gradient/layout coupling.** The generator hard-codes the horizontal proportions of drawTime. If they change,
  the joins stop matching. Mitigation: named constants in the tool, and a comment cross-reference in both places.
- **Gap symmetry is a rasterisation detail.** Insetting the arc bodies by 1° and placing ticks and caps with
  Math.round should fix it. Fallback: derive the gap from pixels via asin.
- **Burn-in.** Brighter accents only appear in active mode. drawLowPower is untouched, which is enforced by T3's verify.
- **Glyph coverage.** "·" and "°" are already used in the row. Verified on fr965 only.

## Rejected alternatives
- Runtime gradient text: Monkey C has no gradient fill for text.
- Dropping the metric icons: this would leave 4 dead drawables. We keep them small, next to the caption.
- Splitting the view across parallel tasks: a single file can't be partitioned safely.
- Rebuilding digits from the original font: the font isn't available. The existing alpha is reused as the mask.

## Proof
- `python tools/gen_digit_gradient.py --check`: sizes and alpha match HEAD, and colors match the gradient within ±2.
- Icon colors are asserted exactly (T2 verify).
- Release builds for fr965 and venu3 print BUILD SUCCESSFUL with no new warnings. The test build passes.
- The simulator unit tests pass: the existing 15 plus the new ones.
- Simulator screenshots: active (12h and 24h, with and without weather, a zero-value metric) and always-on
  (compared with the current one), on fr965 and venu3. Gap symmetry is measured on the fr965 screenshot.

## Drift from plan
- T1: none. Added 13 unit tests; test build failed first with undefined symbols, then passed (red/green).
- T2: none. Slot widths verified against `drawTime()` (dwFull 72, dwColon 39, kern 2, total 335; digits 120x180, colon 60x180).
- T3: arc caps now use radius `arcStroke/2.0` (was `-1`) and bodies are inset 1 degree for gap symmetry.
  `labelRadius` reduced from 148 to `130 * scale` and label padding set to `10 * scale` so label blocks stay inside the band.
  Files kept CRLF.
  Later revisions: captions use a cached vector font (`getVectorFont` about 15*scale, `FONT_XTINY` fallback) with the icon scaled to caption height.
- User decision 2026-11-05: R4 (thin arcs + outer ring), R7 (neutral track colour) and R8 (symmetric gaps) were dropped.
  Arc geometry reverted to the original (24*scale stroke, original radius, no outer ring, track 0x1e1e1e, original ticks/gaps), so the 1-degree
  inset and `arcStroke/2.0` cap radius above no longer apply. Kept: full-saturation accents (R1) and the zero/no-data start dot (R6).

## Results
- T1: done. `monkeyc -t fr965` BUILD SUCCESSFUL.
- T2: done. Verify output: "OK: 41 digit PNGs match HEAD alpha and gradient; icon mismatches: []". Preview at `.agent-runs/visual-refresh/t2-preview.png`.
- T3: done. Release builds for fr965 and venu3 BUILD SUCCESSFUL with no warnings; no diff hunks in `drawLowPower`.
  fr965 simulator screenshot (`.agent-runs/visual-refresh/t3-fr965.png`) looks correct: labels inside arcs, no overlap, row centered.
- Orchestrator: unit tests 28/28 pass in the simulator (fr965).
- fr965 screenshot `.agent-runs/visual-refresh/t3-fr965-r2.png` checked by the orchestrator.
- venu3 visual check: not done. R8 gap-symmetry check is moot (R8 dropped).
