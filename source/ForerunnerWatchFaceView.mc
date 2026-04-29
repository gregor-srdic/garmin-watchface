using Toybox.Graphics as Gfx;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;
using Toybox.Weather;
using Toybox.ActivityMonitor;
using Toybox.Complications;

// Forerunner Watch Face — round AMOLED, 454×454
// Layout: 4 arc gauges around the bezel + bitmap time digits + date/weather row

class ForerunnerWatchFaceView extends WatchUi.WatchFace {
    // ── Palette ───────────────────────────────────────────────────────────────

    private const COLOR_BG = 0x000000;
    private const COLOR_TRACK = 0x2f2f2f;
    private const COLOR_DIM = 0x8a8a8a;
    private const COLOR_DIVIDER = 0x444444;

    // Arc accent colors — fixed per position, independent of complication type
    private const COLOR_ARC_0 = 0xffa040; // top-right
    private const COLOR_ARC_1 = 0xff7da3; // bottom-right
    private const COLOR_ARC_2 = 0x4a9eff; // bottom-left
    private const COLOR_ARC_3 = 0xff4d4d; // top-left

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

        // Allocate 4 complication slot IDs (0–3). Users assign a data field to each
        // slot via the Garmin Connect watch face settings. Slots map to arc positions:
        // 0=top-right, 1=bottom-right, 2=bottom-left, 3=top-left.
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
            if (Complications has :registerComplicationChangeCallback) {
                Complications.registerComplicationChangeCallback(
                    method(:onComplicationChanged)
                );
            }
        }
    }

    // Triggered when the user reassigns a slot in Garmin Connect.
    function onComplicationChanged(complicationId as Complications.Id) as Void {
        WatchUi.requestUpdate();
    }

    function onLayout(dc) {
        screenW = dc.getWidth();
        screenH = dc.getHeight();
        cx = screenW / 2;
        cy = screenH / 2;

        scale = screenW.toFloat() / 454.0;
        arcStroke = (16.0 * scale).toNumber();
        arcRadius = screenW / 2 - arcStroke / 2;
        labelRadius = (148.0 * scale).toNumber();

        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
    }

    function onShow() {}
    function onHide() {}
    function onExitSleep() {}
    function onEnterSleep() {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        dc.setColor(COLOR_BG, COLOR_BG);
        dc.clear();

        var comps = readComplications();
        drawArcs(dc, comps);
        drawCardinalTicks(dc);
        drawTime(dc);
        drawDateWeatherRow(dc);
        drawArcLabels(dc, comps);
    }

    // ── Complication data ─────────────────────────────────────────────────────

    function readComplications() as Lang.Array<Complications.Complication?> {
        var comps = new Lang.Array<Complications.Complication?>[4];
        if (_compIds != null) {
            for (var i = 0; i < 4; i++) {
                comps[i] = Complications.getComplication(_compIds[i]);
            }
        }
        return comps;
    }

    // Returns a reasonable arc-fill maximum for each known complication type.
    function getCompMax(type) {
        if (type == Complications.COMPLICATION_TYPE_HEART_RATE) {
            return 200;
        }
        if (type == Complications.COMPLICATION_TYPE_STRESS) {
            return 100;
        }
        if (type == Complications.COMPLICATION_TYPE_BODY_BATTERY) {
            return 100;
        }
        if (type == Complications.COMPLICATION_TYPE_CALORIES) {
            return 5000;
        }
        if (type == Complications.COMPLICATION_TYPE_STEPS) {
            return 10000;
        }
        if (type == Complications.COMPLICATION_TYPE_FLOORS_CLIMBED) {
            return 50;
        }
        if (type == Complications.COMPLICATION_TYPE_WEEKLY_RUN_DISTANCE) {
            return 50000;
        }
        return 100;
    }

    // ── Arcs ──────────────────────────────────────────────────────────────────

    function drawArcs(
        dc as Gfx.Dc,
        comps as Lang.Array<Complications.Complication?>
    ) as Void {
        var colors = [COLOR_ARC_0, COLOR_ARC_1, COLOR_ARC_2, COLOR_ARC_3];
        var arcStarts = [5, 95, 185, 275];
        var arcEnds = [85, 175, 265, 355];

        dc.setPenWidth(arcStroke);

        for (var i = 0; i < 4; i++) {
            var startD = arcStarts[i];
            var endD = arcEnds[i];
            var color = colors[i];
            var value = 0;
            var maxV = 100;

            var comp = comps[i];
            var compType = comp.getType();
            if (comp != null && comp.value != null) {
                value = comp.value.toNumber();
                if (compType == Complications.COMPLICATION_TYPE_CALORIES) {
                    var info = ActivityMonitor.getInfo();
                    if (info.calories != null) {
                        value = info.calories;
                    }
                }
                maxV = getCompMax(compType);
            }

            var fillEnd = startD + ((endD - startD) * value) / maxV;
            if (fillEnd < startD) {
                fillEnd = startD;
            }
            if (fillEnd > endD) {
                fillEnd = endD;
            }

            dc.setColor(COLOR_TRACK, Gfx.COLOR_TRANSPARENT);
            drawDesignArc(dc, cx, cy, arcRadius, startD, endD);

            if (fillEnd > startD) {
                dc.setColor(color, Gfx.COLOR_TRANSPARENT);
                drawDesignArc(dc, cx, cy, arcRadius, startD, fillEnd);
            }
        }
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
        dc.setPenWidth(2);

        var rOuter = arcRadius - arcStroke - 4;
        var rInner = arcRadius - arcStroke - 12;
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
        var h = clock.hour.format("%02d");
        var m = clock.min.format("%02d");

        // Position index: 0=h1, 1=h2, 2=colon, 3=m1, 4=m2
        var glyphs = [
            h.substring(0, 1),
            h.substring(1, 2),
            ":",
            m.substring(0, 1),
            m.substring(1, 2),
        ];

        var bmps = new [5];
        for (var i = 0; i < 5; i++) {
            bmps[i] = loadDigitBitmap(i, glyphs[i]);
        }

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
            return WatchUi.loadResource(Rez.Drawables.DigitColon);
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

        var timeRenderH = (108.0 * scale).toNumber();
        var segmentHeight = cy - timeRenderH / 2 - arcStroke;

        dc.setColor(COLOR_DIM, Gfx.COLOR_TRANSPARENT);

        // Date — centered in the gap above the time block
        var font = Gfx.FONT_SYSTEM_XTINY;
        var fontH = Gfx.getFontHeight(font);
        var dateY = cy - timeRenderH / 2 - segmentHeight / 2 - fontH;
        dc.drawText(cx, dateY, font, dateStr, Gfx.TEXT_JUSTIFY_CENTER);

        // Temperature + icon — centered in the gap below the time block
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
                var icon = WatchUi.loadResource(iconRes);
                drawScaledBitmap(dc, icon, x, weatherY, iconSize, iconSize);
                x += iconSize + gap;
            }
            dc.drawText(x, weatherY, font, tempStr, Gfx.TEXT_JUSTIFY_LEFT);
        }
    }

    // ── Arc value labels ──────────────────────────────────────────────────────

    // Each slot shows two lines: value (colored, large) nearest to center,
    // and the complication's short label (dim, small) toward the bezel.
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
        var valFont = Gfx.FONT_TINY;
        var valFontH = Gfx.getFontHeight(valFont);
        var pad = (14 * scale).toNumber();

        for (var i = 0; i < 4; i++) {
            var comp = comps[i];
            var color = colors[i];
            var midDeg = midAngles[i];
            var above = aboveCenter[i];
            var icon = icons[i];

            var valStr = "--";
            if (comp != null) {
                if (comp.value != null) {
                    var val = comp.value.toNumber();
                    var compType = comp.getType();
                    if (compType == Complications.COMPLICATION_TYPE_CALORIES) {
                        var info = ActivityMonitor.getInfo();
                        if (info.calories != null) {
                            val = info.calories;
                        }
                    }
                    valStr = val.format("%d");
                }
            }
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

            var iconSize = 32;
            System.println("iconSize: " + iconSize);
            var iconGap = (4 * scale).toNumber();
            var bmp = WatchUi.loadResource(icon);
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
    function readTemp() {
        if (_tempCompId == null) {
            return null;
        }
        var comp = Complications.getComplication(_tempCompId);
        if (comp.value == null) {
            return null;
        }
        var t = comp.value.toNumber();
        if (
            System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE
        ) {
            t = (t * 9) / 5 + 32; // °C → °F
        }
        return t;
    }

    // Maps a Weather condition code to a drawable resource ID, or null if unknown.
    function readWeatherIcon() {
        if (_weatherCompId == null) {
            return null;
        }
        var comp = Complications.getComplication(_weatherCompId);
        if (comp.value == null) {
            return null;
        }

        var c = comp.value.toNumber();

        if (
            c == Weather.CONDITION_CLEAR ||
            c == Weather.CONDITION_FAIR ||
            c == Weather.CONDITION_MOSTLY_CLEAR ||
            c == Weather.CONDITION_PARTLY_CLEAR ||
            c == Weather.CONDITION_THIN_CLOUDS
        ) {
            return Rez.Drawables.WeatherSun;
        } else if (
            c == Weather.CONDITION_CLOUDY ||
            c == Weather.CONDITION_MOSTLY_CLOUDY ||
            c == Weather.CONDITION_PARTLY_CLOUDY
        ) {
            return Rez.Drawables.WeatherCloud;
        } else if (
            c == Weather.CONDITION_FOG ||
            c == Weather.CONDITION_HAZY ||
            c == Weather.CONDITION_HAZE ||
            c == Weather.CONDITION_MIST ||
            c == Weather.CONDITION_DRIZZLE ||
            c == Weather.CONDITION_SMOKE ||
            c == Weather.CONDITION_DUST ||
            c == Weather.CONDITION_SAND ||
            c == Weather.CONDITION_SANDSTORM ||
            c == Weather.CONDITION_VOLCANIC_ASH
        ) {
            return Rez.Drawables.WeatherFog;
        } else if (c == Weather.CONDITION_HAIL) {
            return Rez.Drawables.WeatherHail;
        } else if (
            c == Weather.CONDITION_RAIN ||
            c == Weather.CONDITION_LIGHT_RAIN ||
            c == Weather.CONDITION_HEAVY_RAIN ||
            c == Weather.CONDITION_SCATTERED_SHOWERS ||
            c == Weather.CONDITION_SHOWERS ||
            c == Weather.CONDITION_LIGHT_SHOWERS ||
            c == Weather.CONDITION_HEAVY_SHOWERS ||
            c == Weather.CONDITION_CHANCE_OF_SHOWERS ||
            c == Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN ||
            c == Weather.CONDITION_FREEZING_RAIN ||
            c == Weather.CONDITION_UNKNOWN_PRECIPITATION
        ) {
            return Rez.Drawables.WeatherRain;
        } else if (
            c == Weather.CONDITION_SNOW ||
            c == Weather.CONDITION_LIGHT_SNOW ||
            c == Weather.CONDITION_HEAVY_SNOW ||
            c == Weather.CONDITION_WINTRY_MIX ||
            c == Weather.CONDITION_LIGHT_RAIN_SNOW ||
            c == Weather.CONDITION_HEAVY_RAIN_SNOW ||
            c == Weather.CONDITION_RAIN_SNOW ||
            c == Weather.CONDITION_CHANCE_OF_SNOW ||
            c == Weather.CONDITION_CHANCE_OF_RAIN_SNOW ||
            c == Weather.CONDITION_CLOUDY_CHANCE_OF_SNOW ||
            c == Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN_SNOW ||
            c == Weather.CONDITION_FLURRIES ||
            c == Weather.CONDITION_SLEET ||
            c == Weather.CONDITION_ICE_SNOW
        ) {
            return Rez.Drawables.WeatherSnow;
        } else if (c == Weather.CONDITION_TORNADO) {
            return Rez.Drawables.WeatherTornado;
        } else if (
            c == Weather.CONDITION_THUNDERSTORMS ||
            c == Weather.CONDITION_SCATTERED_THUNDERSTORMS ||
            c == Weather.CONDITION_CHANCE_OF_THUNDERSTORMS ||
            c == Weather.CONDITION_HURRICANE ||
            c == Weather.CONDITION_TROPICAL_STORM
        ) {
            return Rez.Drawables.WeatherThunderstorm;
        } else if (
            c == Weather.CONDITION_SQUALL ||
            c == Weather.CONDITION_WINDY
        ) {
            return Rez.Drawables.WeatherWind;
        } else if (c == Weather.CONDITION_ICE) {
            return Rez.Drawables.WeatherIce;
        }

        return null;
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
