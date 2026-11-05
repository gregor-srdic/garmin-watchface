using Toybox.Graphics as Gfx;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;
using Toybox.Weather;
using Toybox.Complications;

// Arches Watch Face — round AMOLED, 454×454
// Layout: 4 arc gauges around the bezel + bitmap time digits + date/weather row

class ArchesWatchFaceView extends WatchUi.WatchFace {
    // ── Palette ───────────────────────────────────────────────────────────────

    private const COLOR_BG = 0x000000;
    private const COLOR_TRACK = 0x1e1e1e; // 65% of the original 0x2f2f2f
    private const COLOR_DIM = 0x8a8a8a;
    private const COLOR_DIVIDER = 0x444444;

    // Arc accent colors — fixed per position, independent of complication type.
    // Dimmed to 65% of the original design values to slow AMOLED image
    // retention / burn-in; keep in sync with BRIGHTNESS in tools/gen_arc_icons.py.
    private const COLOR_ARC_0 = 0xa56829; // top-right (65% of 0xffa040)
    private const COLOR_ARC_1 = 0xa55169; // bottom-right (65% of 0xff7da3)
    private const COLOR_ARC_2 = 0x3066a5; // bottom-left (65% of 0x4a9eff)
    private const COLOR_ARC_3 = 0xa53232; // top-left (65% of 0xff4d4d)

    // ── Layout ────────────────────────────────────────────────────────────────

    private var screenW;
    private var screenH;
    private var cx;
    private var cy;
    private var arcRadius;
    private var arcStroke;
    private var labelRadius;
    private var scale;

    // ── Digit resources ───────────────────────────────────────────────────────

    private var _digitsH1 as Lang.Array<Lang.ResourceId>;
    private var _digitsH2 as Lang.Array<Lang.ResourceId>;
    private var _digitsM1 as Lang.Array<Lang.ResourceId>;
    private var _digitsM2 as Lang.Array<Lang.ResourceId>;

    // ── Complication slot IDs ─────────────────────────────────────────────────

    private var _compIds as Lang.Array<Complications.Id>?;
    private var _tempCompId as Complications.Id?;
    private var _weatherCompId as Complications.Id?;

    // True while the device is in always-on (low power) mode.
    private var _inLowPower = false;

    // ── Bitmap caches ─────────────────────────────────────────────────────────
    // The face redraws every second for a few seconds after a wrist raise.
    // Loading bitmaps on every redraw wastes battery, so:
    //   - metric icons and the colon load once,
    //   - the four digit bitmaps reload only when the shown time changes,
    //   - the weather icon reloads only when the condition (or day/night) changes.
    private var _iconBmps as Lang.Array? = null;
    private var _colonBmp = null;
    private var _timeKey as Lang.String? = null;
    private var _digitBmps as Lang.Array? = null;
    private var _weatherIconRes = null;
    private var _weatherBmp = null;

    // Sunrise/sunset (seconds since epoch) for the weather location, refreshed
    // at most once per hour. Null when unavailable (fixed-hours fallback).
    private var _sunHourKey = -1;
    private var _sunrise as Lang.Number? = null;
    private var _sunset as Lang.Number? = null;

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    function initialize() {
        WatchFace.initialize();

        _digitsH1 =
            [
                Rez.Drawables.DigitH1_0,
                Rez.Drawables.DigitH1_1,
                Rez.Drawables.DigitH1_2,
                Rez.Drawables.DigitH1_3,
                Rez.Drawables.DigitH1_4,
                Rez.Drawables.DigitH1_5,
                Rez.Drawables.DigitH1_6,
                Rez.Drawables.DigitH1_7,
                Rez.Drawables.DigitH1_8,
                Rez.Drawables.DigitH1_9,
            ] as Lang.Array<Lang.ResourceId>;
        _digitsH2 =
            [
                Rez.Drawables.DigitH2_0,
                Rez.Drawables.DigitH2_1,
                Rez.Drawables.DigitH2_2,
                Rez.Drawables.DigitH2_3,
                Rez.Drawables.DigitH2_4,
                Rez.Drawables.DigitH2_5,
                Rez.Drawables.DigitH2_6,
                Rez.Drawables.DigitH2_7,
                Rez.Drawables.DigitH2_8,
                Rez.Drawables.DigitH2_9,
            ] as Lang.Array<Lang.ResourceId>;
        _digitsM1 =
            [
                Rez.Drawables.DigitM1_0,
                Rez.Drawables.DigitM1_1,
                Rez.Drawables.DigitM1_2,
                Rez.Drawables.DigitM1_3,
                Rez.Drawables.DigitM1_4,
                Rez.Drawables.DigitM1_5,
                Rez.Drawables.DigitM1_6,
                Rez.Drawables.DigitM1_7,
                Rez.Drawables.DigitM1_8,
                Rez.Drawables.DigitM1_9,
            ] as Lang.Array<Lang.ResourceId>;
        _digitsM2 =
            [
                Rez.Drawables.DigitM2_0,
                Rez.Drawables.DigitM2_1,
                Rez.Drawables.DigitM2_2,
                Rez.Drawables.DigitM2_3,
                Rez.Drawables.DigitM2_4,
                Rez.Drawables.DigitM2_5,
                Rez.Drawables.DigitM2_6,
                Rez.Drawables.DigitM2_7,
                Rez.Drawables.DigitM2_8,
                Rez.Drawables.DigitM2_9,
            ] as Lang.Array<Lang.ResourceId>;

        // One complication per arc, fixed by type (not user-configurable).
        // Slots map to arc positions: 0=top-right (stress), 1=bottom-right
        // (calories), 2=bottom-left (body battery), 3=top-left (heart rate).
        // Guard required: Complications is unsupported on older simulators/firmware.
        _compIds = null;
        _tempCompId = null;
        _weatherCompId = null;
        if (Toybox has :Complications) {
            _compIds = new Lang.Array<Complications.Id>[4];
            _compIds[0] = new Complications.Id(
                Complications.COMPLICATION_TYPE_STRESS
            );
            _compIds[1] = new Complications.Id(
                Complications.COMPLICATION_TYPE_CALORIES
            );
            _compIds[2] = new Complications.Id(
                Complications.COMPLICATION_TYPE_BODY_BATTERY
            );
            _compIds[3] = new Complications.Id(
                Complications.COMPLICATION_TYPE_HEART_RATE
            );
            _tempCompId = new Complications.Id(
                Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE
            );
            _weatherCompId = new Complications.Id(
                Complications.COMPLICATION_TYPE_CURRENT_WEATHER
            );
        }
    }

    function onLayout(dc) {
        screenW = dc.getWidth();
        screenH = dc.getHeight();
        cx = screenW / 2;
        cy = screenH / 2;

        scale = screenW.toFloat() / 454.0;
        arcStroke = (24.0 * scale).toNumber();
        arcRadius = screenW / 2 - arcStroke / 2;
        labelRadius = (148.0 * scale).toNumber();

        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
    }

    function onShow() {}
    function onHide() {}
    function onExitSleep() {
        _inLowPower = false;
        WatchUi.requestUpdate();
    }
    function onEnterSleep() {
        _inLowPower = true;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        dc.setColor(COLOR_BG, COLOR_BG);
        dc.clear();

        if (_inLowPower) {
            drawLowPower(dc);
            return;
        }

        var comps = readComplications();
        drawArcs(dc, comps);
        drawCardinalTicks(dc);
        drawTime(dc);
        drawDateWeatherRow(dc);
        drawArcLabels(dc, comps);
    }

    // ── Always-on (low power) mode ────────────────────────────────────────────
    //
    // AMOLED burn-in protection: keep well under ~10% of pixels lit, no bright
    // colors, and drift the time by a few pixels each minute so no pixel stays
    // lit continuously. The static full-brightness arcs shown in AOD are what
    // produced the ghost ring this face burned into the panel.
    function drawLowPower(dc) {
        var clock = System.getClockTime();
        var is24Hour = System.getDeviceSettings().is24Hour;
        var t = Lang.format("$1$:$2$", [
            ArchesLogic.hourString(clock.hour, is24Hour),
            clock.min.format("%02d"),
        ]);

        // Cycle through a 5x5 pixel grid of offsets over 25 minutes.
        var dx = (clock.min % 5) - 2;
        var dy = ((clock.min / 5) % 5) - 2;

        dc.setColor(0x555555, Gfx.COLOR_TRANSPARENT);
        dc.drawText(
            cx + dx,
            cy + dy,
            Gfx.FONT_NUMBER_MILD,
            t,
            Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER
        );

        // AM/PM under the time in 12-hour mode: same dim colour, drifts with it.
        if (!is24Hour) {
            var timeH = Gfx.getFontHeight(Gfx.FONT_NUMBER_MILD);
            dc.drawText(
                cx + dx,
                cy + dy + timeH / 2,
                Gfx.FONT_XTINY,
                ArchesLogic.ampmLabel(clock.hour),
                Gfx.TEXT_JUSTIFY_CENTER
            );
        }
    }

    // ── Complication data ─────────────────────────────────────────────────────

    function readComplications() as Lang.Array<Complications.Complication?> {
        var comps = new Lang.Array<Complications.Complication?>[4];
        if (_compIds != null) {
            for (var i = 0; i < 4; i++) {
                comps[i] = ArchesLogic.safeGetComplication(_compIds[i]);
            }
        }
        return comps;
    }

    // ── Arcs ──────────────────────────────────────────────────────────────────

    function drawArcs(
        dc as Gfx.Dc,
        comps as Lang.Array<Complications.Complication?>
    ) as Void {
        var colors = [COLOR_ARC_0, COLOR_ARC_1, COLOR_ARC_2, COLOR_ARC_3];
        var arcStarts = [5, 95, 185, 275];
        var arcEnds = [85, 175, 265, 355];

        for (var i = 0; i < 4; i++) {
            var startD = arcStarts[i];
            var endD = arcEnds[i];
            var color = colors[i];
            var reading = ArchesLogic.slotReading(comps[i]);
            var value = reading[0];
            var maxV = reading[1];

            var fillEnd = startD + ((endD - startD) * value) / maxV;
            if (fillEnd < startD) {
                fillEnd = startD;
            }
            if (fillEnd > endD) {
                fillEnd = endD;
            }

            dc.setColor(COLOR_TRACK, Gfx.COLOR_TRANSPARENT);
            drawThickDesignArc(dc, arcRadius, arcStroke, startD, endD);
            drawArcCap(dc, startD);
            drawArcCap(dc, endD);

            if (fillEnd > startD) {
                dc.setColor(color, Gfx.COLOR_TRANSPARENT);
                drawThickDesignArc(dc, arcRadius, arcStroke, startD, fillEnd);
                drawArcCap(dc, startD);
                drawArcCap(dc, fillEnd);
            }
        }
    }

    // Rounds off an arc end by drawing a filled circle over it, since
    // dc.drawArc only supports flat (butt) line caps.
    function drawArcCap(dc, angleDesign) {
        // Compute the center in floating point — polar() truncates to ints,
        // which biases the cap up/left (radially outward on the left/top of
        // the dial). The half-pixel radius trim keeps the cap flush with the
        // arc's pen width.
        // Round to nearest pixel ourselves — fillCircle truncates float
        // coordinates on this firmware, which biases the cap up/left.
        var rad = ((angleDesign - 90) * Math.PI) / 180.0;
        var x = cx + arcRadius * Math.cos(rad);
        var y = cy + arcRadius * Math.sin(rad);
        dc.fillCircle(Math.round(x), Math.round(y), arcStroke / 2.0 - 1);
    }

    // Draws a thick arc. Normally a single drawArc pass: on current firmware the
    // 24px stroke renders cleanly in one pass on the watch (verified on device).
    // Strokes wider than SPLIT_THRESHOLD fall back to two concentric passes that
    // overlap by several fully-opaque pixels. That fallback exists because some
    // firmware split wide strokes into two passes with a visible anti-aliased
    // seam; overlapping our own passes puts the seam on same-color pixels.
    // The threshold was 16px; it was raised deliberately once the single pass
    // proved seam-free. Lower it again if the seam reappears on a device.
    private const SPLIT_THRESHOLD = 240;

    function drawThickDesignArc(dc, r, stroke, startDesign, endDesign) {
        if (stroke <= SPLIT_THRESHOLD) {
            dc.setPenWidth(stroke);
            drawDesignArc(dc, cx, cy, r, startDesign, endDesign);
            return;
        }
        var pen = stroke / 2 + 2;
        if ((stroke - pen) % 2 != 0) {
            pen += 1;
        }
        var off = (stroke - pen) / 2;
        dc.setPenWidth(pen);
        drawDesignArc(dc, cx, cy, r + off, startDesign, endDesign);
        drawDesignArc(dc, cx, cy, r - off, startDesign, endDesign);
    }

    // Wraps dc.drawArc using design-angle convention (0° = top, CW positive).
    // Garmin's native convention is 0° = east, CCW positive → offset by 90°.
    function drawDesignArc(dc, x, y, r, startDesign, endDesign) {
        dc.drawArc(
            x,
            y,
            r,
            Gfx.ARC_CLOCKWISE,
            90 - startDesign,
            90 - endDesign
        );
    }

    // ── Cardinal tick marks ───────────────────────────────────────────────────

    // Short tick marks at the four arc gap positions to visually separate segments.
    function drawCardinalTicks(dc) {
        dc.setColor(COLOR_DIVIDER, Gfx.COLOR_TRANSPARENT);
        // Odd pen width so the tick centers exactly on the cardinal axis —
        // an even width rasterizes wholly to one side of the line, which made
        // the gaps around the ticks look uneven.
        dc.setPenWidth(3);

        // AMOLED wear protection: drift the ticks radially outward by 0..+4 px
        // on a 5-minute cycle so their pixels don't accumulate wear in one spot.
        var drift = (System.getClockTime().min % 5);
        var rOuter = arcRadius - arcStroke - 4 + drift;
        var rInner = arcRadius - arcStroke - 12 + drift;
        var degrees = [0, 90, 180, 270] as Lang.Array<Lang.Number>;

        for (var i = 0; i < degrees.size(); i++) {
            var p1 = polar(cx, cy, rOuter, degrees[i]);
            var p2 = polar(cx, cy, rInner, degrees[i]);
            dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
        }
    }

    // ── Time (bitmap digits) ──────────────────────────────────────────────────
    //
    // Five glyphs — h1, h2, colon, m1, m2 — are loaded as pre-tinted PNGs
    // (60×90 source) and scaled to ~33% of the screen height at draw time.

    function drawTime(dc) {
        var clock = System.getClockTime();
        var h = ArchesLogic.hourString(
            clock.hour,
            System.getDeviceSettings().is24Hour
        );
        var m = clock.min.format("%02d");

        // Position index: 0=h1, 1=h2, 2=colon, 3=m1, 4=m2
        var glyphs = [
            h.substring(0, 1),
            h.substring(1, 2),
            ":",
            m.substring(0, 1),
            m.substring(1, 2),
        ];

        // Reload digit bitmaps only when the shown time changes.
        var key = h + m;
        if (_digitBmps == null || !key.equals(_timeKey)) {
            _digitBmps = new [5];
            for (var i = 0; i < 5; i++) {
                _digitBmps[i] = loadDigitBitmap(i, glyphs[i]);
            }
            _timeKey = key;
        }
        var bmps = _digitBmps;

        var renderH = (108.0 * scale).toNumber();
        var renderScale = renderH / 90.0;
        var dwFull = (60.0 * renderScale).toNumber();
        var dwColon = (dwFull * 0.55).toNumber(); // colon glyph is narrower
        var kern = (2 * scale).toNumber();

        var widths = [dwFull, dwFull, dwColon, dwFull, dwFull];
        var totalW = dwFull * 4 + dwColon + kern * 4;
        var x = cx - totalW / 2;
        var y = cy - renderH / 2;

        for (var i = 0; i < 5; i++) {
            if (bmps[i] != null) {
                drawScaledBitmap(dc, bmps[i], x, y, widths[i], renderH);
            }
            x += widths[i] + kern;
        }
    }

    // Resolves a digit resource from the cached lookup tables.
    // pos: 0=h1, 1=h2, 2=colon, 3=m1, 4=m2
    function loadDigitBitmap(pos, ch) {
        if (ch.equals(":")) {
            if (_colonBmp == null) {
                _colonBmp = WatchUi.loadResource(Rez.Drawables.DigitColon);
            }
            return _colonBmp;
        }
        var d = ch.toNumber();
        var table =
            pos == 0
                ? _digitsH1
                : pos == 1
                  ? _digitsH2
                  : pos == 3
                    ? _digitsM1
                    : _digitsM2;
        return WatchUi.loadResource(table[d]);
    }

    // Falls back to unscaled drawBitmap on older API levels lacking drawScaledBitmap.
    function drawScaledBitmap(dc, bmp, x, y, w, h) {
        if (dc has :drawScaledBitmap) {
            dc.drawScaledBitmap(x, y, w, h, bmp);
        } else {
            dc.drawBitmap(x, y, bmp);
        }
    }

    // ── Date + weather row ────────────────────────────────────────────────────

    function drawDateWeatherRow(dc) {
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateStr = Lang.format("$1$ $2$", [info.month.toUpper(), info.day]);
        // 12-hour mode: AM/PM goes in the date row ("NOV 5 · PM").
        if (!System.getDeviceSettings().is24Hour) {
            dateStr +=
                " · " + ArchesLogic.ampmLabel(System.getClockTime().hour);
        }

        var timeRenderH = (108.0 * scale).toNumber();
        var segmentHeight = cy - timeRenderH / 2 - arcStroke;

        dc.setColor(COLOR_DIM, Gfx.COLOR_TRANSPARENT);

        // Date — text sits just above the midpoint of the gap above the time
        // block (its bottom edge on the midpoint), mirroring the weather row
        var font = Gfx.FONT_SYSTEM_XTINY;
        var fontH = Gfx.getFontHeight(font);
        var dateY = cy - timeRenderH / 2 - segmentHeight / 2 - fontH;
        dc.drawText(cx, dateY, font, dateStr, Gfx.TEXT_JUSTIFY_CENTER);

        // Temperature + icon — top edge on the midpoint of the gap below the time block
        var temp = readTemp();
        if (temp != null) {
            font = Gfx.FONT_XTINY;
            fontH = Gfx.getFontHeight(font);
            var iconSize = fontH;
            var gap = (4 * scale).toNumber();
            var iconRes = readWeatherIcon();
            var tempStr = temp.toString() + "°";
            var tempW = dc.getTextWidthInPixels(tempStr, font);
            var weatherY = cy + timeRenderH / 2 + segmentHeight / 2;

            var totalW = tempW;
            if (iconRes != null) {
                totalW += iconSize + gap;
            }
            var x = cx - totalW / 2;

            if (iconRes != null) {
                if (iconRes != _weatherIconRes) {
                    _weatherBmp = WatchUi.loadResource(iconRes);
                    _weatherIconRes = iconRes;
                }
                drawScaledBitmap(dc, _weatherBmp, x, weatherY, iconSize, iconSize);
                x += iconSize + gap;
            }
            dc.drawText(x, weatherY, font, tempStr, Gfx.TEXT_JUSTIFY_LEFT);
        }
    }

    // ── Arc value labels ──────────────────────────────────────────────────────

    // Each slot shows a flat icon (pre-tinted to the arc accent color) next
    // to the value, centered on the arc's mid-angle.
    function drawArcLabels(
        dc as Gfx.Dc,
        comps as Lang.Array<Complications.Complication?>
    ) as Void {
        var colors = [COLOR_ARC_0, COLOR_ARC_1, COLOR_ARC_2, COLOR_ARC_3];
        var icons = [
            Rez.Drawables.IconStress,
            Rez.Drawables.IconKcal,
            Rez.Drawables.IconBody,
            Rez.Drawables.IconHR,
        ];
        var midAngles = [45, 135, 225, 315];
        var aboveCenter = [true, false, false, true];

        var timeRenderH = (108.0 * scale).toNumber();
        var valFont = Gfx.FONT_SYSTEM_XTINY;
        var valFontH = Gfx.getFontHeight(valFont);
        var pad = (14 * scale).toNumber();

        // AMOLED wear protection: drift the labels vertically by -2..+2 px on
        // a 5-minute cycle so their pixels don't accumulate wear in one spot.
        // Mirrored about the screen center: top labels move up while bottom
        // labels move down (and vice versa), keeping both equidistant from
        // the middle.
        var drift = (System.getClockTime().min % 5) - 2;

        if (_iconBmps == null) {
            _iconBmps = new [4];
            for (var j = 0; j < 4; j++) {
                _iconBmps[j] = WatchUi.loadResource(icons[j]);
            }
        }

        for (var i = 0; i < 4; i++) {
            var comp = comps[i];
            var color = colors[i];
            var midDeg = midAngles[i];
            var above = aboveCenter[i];

            var val = ArchesLogic.slotValue(comp);
            var valStr = val == null ? "--" : val.format("%d");
            var lx = polar(cx, cy, labelRadius, midDeg)[0];
            // anchor = edge of the label block closest to the time display
            var anchor = cy + (above ? -1 : 1) * (timeRenderH / 2 + pad);

            var valY;
            if (above) {
                // block sits above anchor: value at bottom, label above it
                valY = anchor - valFontH;
            } else {
                // block sits below anchor: value at top, label below it
                valY = anchor;
            }
            valY += above ? -drift : drift;

            // Icons are flat silhouettes pre-tinted to the arc accent color,
            // sized to roughly the numerals' cap height so the value stays
            // the dominant element.
            var iconSize = (20.0 * scale).toNumber();
            var iconGap = (6 * scale).toNumber();
            var bmp = _iconBmps[i];
            var textW = dc.getTextWidthInPixels(valStr, valFont);
            var totalW = iconSize + iconGap + textW;
            var startX = lx - totalW / 2;

            dc.setColor(color, Gfx.COLOR_TRANSPARENT);
            drawScaledBitmap(
                dc,
                bmp,
                startX,
                valY + (valFontH - iconSize) / 2,
                iconSize,
                iconSize
            );
            dc.drawText(
                startX + iconSize + iconGap,
                valY,
                valFont,
                valStr,
                Gfx.TEXT_JUSTIFY_LEFT
            );
        }
    }

    // ── Weather helpers ───────────────────────────────────────────────────────

    // Returns current temperature in device-preferred units, or null if unavailable.
    // The complication always reports Celsius (Float since API 5.0).
    function readTemp() {
        var comp = ArchesLogic.safeGetComplication(_tempCompId);
        if (comp == null || comp.value == null) {
            return null;
        }
        return ArchesLogic.displayTemp(
            comp.value as Lang.Numeric,
            System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE
        );
    }

    // Night = before sunrise / after sunset at the weather location, using
    // the location the weather data already carries (no GPS, no extra
    // permission). Falls back to 20:00–06:00 when that isn't available.
    function isNightNow() as Lang.Boolean {
        var clock = System.getClockTime();
        if (clock.hour != _sunHourKey) {
            _sunHourKey = clock.hour;
            _sunrise = null;
            _sunset = null;
            try {
                var cond = Weather.getCurrentConditions();
                if (
                    cond != null &&
                    cond.observationLocationPosition != null &&
                    Weather has :getSunrise
                ) {
                    var now = Time.now();
                    var sr = Weather.getSunrise(
                        cond.observationLocationPosition,
                        now
                    );
                    var ss = Weather.getSunset(
                        cond.observationLocationPosition,
                        now
                    );
                    if (sr != null && ss != null) {
                        _sunrise = sr.value();
                        _sunset = ss.value();
                    }
                }
            } catch (e) {
                // Keep the fixed-hours fallback.
            }
        }
        return ArchesLogic.isNight(
            Time.now().value(),
            _sunrise,
            _sunset,
            clock.hour
        );
    }

    // Weather icon for the current condition, with a moon instead of the sun
    // at night. Null if there's no data or the condition is unknown.
    function readWeatherIcon() {
        var comp = ArchesLogic.safeGetComplication(_weatherCompId);
        if (comp == null || comp.value == null) {
            return null;
        }
        return ArchesLogic.weatherIconFor(
            (comp.value as Lang.Numeric).toNumber(),
            isNightNow()
        );
    }

    // ── Geometry ──────────────────────────────────────────────────────────────

    // Converts design-angle polar coordinates to screen (x, y).
    // Design convention: 0° = top, clockwise positive (matches clock face intuition).
    function polar(ox, oy, r, angleDesign) as Lang.Array<Lang.Number> {
        var rad = ((angleDesign - 90) * Math.PI) / 180.0;
        return [
            (ox + r * Math.cos(rad)).toNumber(),
            (oy + r * Math.sin(rad)).toNumber(),
        ];
    }
}
