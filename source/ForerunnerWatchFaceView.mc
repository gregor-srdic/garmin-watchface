using Toybox.Graphics as Gfx;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;
using Toybox.ActivityMonitor;
using Toybox.SensorHistory;
using Toybox.UserProfile;
using Toybox.Weather;

// Forerunner Watch Face — round AMOLED, 454×454
// Layout: 4 arc gauges around the bezel + bitmap time digits + date/weather row

class ForerunnerWatchFaceView extends WatchUi.WatchFace {
    // ── Palette ───────────────────────────────────────────────────────────────

    private const COLOR_BG = 0x000000;
    private const COLOR_TRACK = 0x2f2f2f;
    private const COLOR_DIM = 0x8a8a8a;
    private const COLOR_DIVIDER = 0x444444;

    // Arc accent colors (one per metric)
    private const COLOR_HR = 0xff4d4d;
    private const COLOR_STRESS = 0xffa040;
    private const COLOR_BODY = 0x4a9eff;
    private const COLOR_KCAL = 0xff7da3;

    // ── Layout ────────────────────────────────────────────────────────────────

    private var screenW;
    private var screenH;
    private var cx;
    private var cy;
    private var arcRadius;
    private var arcStroke;
    private var labelRadius;
    private var scale;

    // ── Sensor state ──────────────────────────────────────────────────────────

    // Last-known valid readings — survive transient sensor dropouts
    private var _lastHr = 0;
    private var _lastStress = 0;
    private var _lastBody = 0;

    // ── Digit resources ───────────────────────────────────────────────────────

    // Lookup tables cached here to avoid re-allocating 40 arrays on every frame
    private var _digitsH1;
    private var _digitsH2;
    private var _digitsM1;
    private var _digitsM2;

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    function initialize() {
        WatchFace.initialize();

        _digitsH1 = [
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
        ];
        _digitsH2 = [
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
        ];
        _digitsM1 = [
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
        ];
        _digitsM2 = [
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
        ];
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

        var data = readData();
        drawArcs(dc, data);
        drawCardinalTicks(dc);
        drawTime(dc);
        drawDateWeatherRow(dc);
        drawArcLabels(dc, data);
    }

    // ── Data reads ────────────────────────────────────────────────────────────

    function readData() {
        var info = ActivityMonitor.getInfo();
        return {
            :hr => readHr(),
            :stress => readStress(),
            :body => readBodyBattery(),
            :kcal => info.calories != null ? info.calories : 0,
        };
    }

    function readHr() {
        var hr = 0;
        var s = ActivityMonitor.getHeartRateHistory(1, true).next();
        if (s != null && s.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
            hr = s.heartRate;
        }
        if (hr != 0) {
            _lastHr = hr;
        } else {
            hr = _lastHr;
        }
        return hr;
    }

    function readStress() {
        if (
            !(Toybox has :SensorHistory) ||
            !(SensorHistory has :getStressHistory)
        ) {
            return _lastStress;
        }
        var value = readSensorIterValue(
            SensorHistory.getStressHistory({ :period => 1 })
        );
        if (value != 0) {
            _lastStress = value;
        } else {
            value = _lastStress;
        }
        return value;
    }

    function readBodyBattery() {
        if (
            !(Toybox has :SensorHistory) ||
            !(SensorHistory has :getBodyBatteryHistory)
        ) {
            return _lastBody;
        }
        var value = readSensorIterValue(
            SensorHistory.getBodyBatteryHistory({ :period => 1 })
        );
        if (value != 0) {
            _lastBody = value;
        } else {
            value = _lastBody;
        }
        return value;
    }

    // Pulls the first .data value from a SensorHistory iterator, or 0 on miss.
    function readSensorIterValue(iter) {
        if (iter == null) {
            return 0;
        }
        var s = iter.next();
        return s != null && s.data != null ? s.data.toNumber() : 0;
    }

    // Returns current temperature in device-preferred units, or null if unavailable.
    function readTemp() {
        if (!(Toybox has :Weather) || !(Weather has :getCurrentConditions)) {
            return null;
        }
        var cur = Weather.getCurrentConditions();
        if (cur == null || cur.temperature == null) {
            return null;
        }

        var t = cur.temperature;
        if (
            System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE
        ) {
            t = (t * 9) / 5 + 32; // °C → °F
        }
        return t.toNumber();
    }

    // Maps a Weather condition code to a unicode icon, or "" if unknown.
    function readWeatherIcon() {
        if (!(Toybox has :Weather) || !(Weather has :getCurrentConditions)) {
            return "";
        }
        var cur = Weather.getCurrentConditions();
        if (cur == null || cur.condition == null) {
            return "";
        }

        var c = cur.condition;
        if (c == Weather.CONDITION_CLEAR) {
            return "☀"; // 0
        } else if (c == Weather.CONDITION_PARTLY_CLOUDY) {
            return "🌤"; // 1
        } else if (c == Weather.CONDITION_MOSTLY_CLOUDY) {
            return "🌥"; // 2
        } else if (c == Weather.CONDITION_RAIN) {
            return "🌧"; // 3
        } else if (c == Weather.CONDITION_SNOW) {
            return "❄"; // 4
        } else if (c == Weather.CONDITION_WINDY) {
            return "🌪"; // 5
        } else if (c == Weather.CONDITION_THUNDERSTORMS) {
            return "⛈"; // 6
        } else if (c == Weather.CONDITION_WINTRY_MIX) {
            return "🌨"; // 7
        } else if (c == Weather.CONDITION_FOG) {
            return "🌫"; // 8
        } else if (c == Weather.CONDITION_HAZY) {
            return "🌫"; // 9
        } else if (c == Weather.CONDITION_HAIL) {
            return "🌨"; // 10
        } else if (c == Weather.CONDITION_SCATTERED_SHOWERS) {
            return "🌦"; // 11
        } else if (c == Weather.CONDITION_SCATTERED_THUNDERSTORMS) {
            return "⛈"; // 12
        } else if (c == Weather.CONDITION_UNKNOWN_PRECIPITATION) {
            return "🌧"; // 13
        } else if (c == Weather.CONDITION_LIGHT_RAIN) {
            return "🌦"; // 14
        } else if (c == Weather.CONDITION_HEAVY_RAIN) {
            return "🌧"; // 15
        } else if (c == Weather.CONDITION_LIGHT_SNOW) {
            return "🌨"; // 16
        } else if (c == Weather.CONDITION_HEAVY_SNOW) {
            return "❄"; // 17
        } else if (c == Weather.CONDITION_LIGHT_RAIN_SNOW) {
            return "🌨"; // 18
        } else if (c == Weather.CONDITION_HEAVY_RAIN_SNOW) {
            return "🌨"; // 19
        } else if (c == Weather.CONDITION_CLOUDY) {
            return "☁"; // 20
        } else if (c == Weather.CONDITION_RAIN_SNOW) {
            return "🌨"; // 21
        } else if (c == Weather.CONDITION_PARTLY_CLEAR) {
            return "🌤"; // 22
        } else if (c == Weather.CONDITION_MOSTLY_CLEAR) {
            return "🌤"; // 23
        } else if (c == Weather.CONDITION_LIGHT_SHOWERS) {
            return "🌦"; // 24
        } else if (c == Weather.CONDITION_SHOWERS) {
            return "🌧"; // 25
        } else if (c == Weather.CONDITION_HEAVY_SHOWERS) {
            return "🌧"; // 26
        } else if (c == Weather.CONDITION_CHANCE_OF_SHOWERS) {
            return "🌦"; // 27
        } else if (c == Weather.CONDITION_CHANCE_OF_THUNDERSTORMS) {
            return "⛈"; // 28
        } else if (c == Weather.CONDITION_MIST) {
            return "🌫"; // 29
        } else if (c == Weather.CONDITION_DUST) {
            return "🌪"; // 30
        } else if (c == Weather.CONDITION_DRIZZLE) {
            return "🌦"; // 31
        } else if (c == Weather.CONDITION_TORNADO) {
            return "🌪"; // 32
        } else if (c == Weather.CONDITION_SMOKE) {
            return "🌫"; // 33
        } else if (c == Weather.CONDITION_ICE) {
            return "❄"; // 34
        } else if (c == Weather.CONDITION_SAND) {
            return "🌪"; // 35
        } else if (c == Weather.CONDITION_SQUALL) {
            return "🌫"; // 36
        } else if (c == Weather.CONDITION_SANDSTORM) {
            return "🌪"; // 37
        } else if (c == Weather.CONDITION_VOLCANIC_ASH) {
            return "🌫"; // 38
        } else if (c == Weather.CONDITION_HAZE) {
            return "🌫"; // 39
        } else if (c == Weather.CONDITION_FAIR) {
            return "🌤"; // 40
        } else if (c == Weather.CONDITION_HURRICANE) {
            return "⛈"; // 41
        } else if (c == Weather.CONDITION_TROPICAL_STORM) {
            return "⛈"; // 42
        } else if (c == Weather.CONDITION_CHANCE_OF_SNOW) {
            return "🌨"; // 43
        } else if (c == Weather.CONDITION_CHANCE_OF_RAIN_SNOW) {
            return "🌨"; // 44
        } else if (c == Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN) {
            return "🌦"; // 45
        } else if (c == Weather.CONDITION_CLOUDY_CHANCE_OF_SNOW) {
            return "🌨"; // 46
        } else if (c == Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN_SNOW) {
            return "🌨"; // 47
        } else if (c == Weather.CONDITION_FLURRIES) {
            return "🌨"; // 48
        } else if (c == Weather.CONDITION_FREEZING_RAIN) {
            return "🌧"; // 49
        } else if (c == Weather.CONDITION_SLEET) {
            return "🌨"; // 50
        } else if (c == Weather.CONDITION_ICE_SNOW) {
            return "❄"; // 51
        } else if (c == Weather.CONDITION_THIN_CLOUDS) {
            return "🌤"; // 52
        }
        return ""; // CONDITION_UNKNOWN (53) or any future code
    }

    // ── Arcs ──────────────────────────────────────────────────────────────────

    // Each arc entry: [startDeg, endDeg, value, maxValue, color]
    // Angles follow design convention: 0° = top, clockwise positive.
    function drawArcs(dc, data) {
        var arcs = [
            [0, 90, data[:stress], 100, COLOR_STRESS],
            [90, 180, data[:kcal], 5000, COLOR_KCAL],
            [180, 270, data[:body], 100, COLOR_BODY],
            [270, 360, data[:hr], 200, COLOR_HR],
        ];

        dc.setPenWidth(arcStroke);

        for (var i = 0; i < arcs.size(); i++) {
            var a = arcs[i];
            var startD = a[0];
            var endD = a[1];
            var value = a[2];
            var maxV = a[3];
            var color = a[4];

            var fillEnd = startD + ((endD - startD) * value) / maxV;
            if (fillEnd < startD) {
                fillEnd = startD;
            }
            if (fillEnd > endD) {
                fillEnd = endD;
            }

            // Dark background track with rounded caps
            dc.setColor(COLOR_TRACK, Gfx.COLOR_TRANSPARENT);
            drawDesignArc(dc, cx, cy, arcRadius, startD, endD);
            drawArcCap(dc, cx, cy, arcRadius, startD, COLOR_TRACK);
            drawArcCap(dc, cx, cy, arcRadius, endD, COLOR_TRACK);

            // Colored fill on top, only when non-zero
            if (fillEnd > startD) {
                dc.setColor(color, Gfx.COLOR_TRANSPARENT);
                drawDesignArc(dc, cx, cy, arcRadius, startD, fillEnd);
                drawArcCap(dc, cx, cy, arcRadius, startD, color);
                drawArcCap(dc, cx, cy, arcRadius, fillEnd, color);
            }
        }
    }

    // Filled circle at an arc endpoint to produce a rounded cap.
    function drawArcCap(dc, ox, oy, r, angleDesign, color) {
        // var p = polar(ox, oy, r, angleDesign);
        // dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        // dc.fillCircle(p[0], p[1], arcStroke / 2);
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
        var degrees = [0, 90, 180, 270];

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
            var iconStr = readWeatherIcon();
            var tempStr = temp.toString() + "°";
            var iconW = dc.getTextWidthInPixels(iconStr, font);
            var tempW = dc.getTextWidthInPixels(tempStr, font);
            var x = cx - (iconW + tempW) / 2;
            var weatherY = cy + timeRenderH / 2 + segmentHeight / 2;
            dc.drawText(x, weatherY, font, iconStr, Gfx.TEXT_JUSTIFY_LEFT);
            dc.drawText(
                x + iconW,
                weatherY,
                font,
                tempStr,
                Gfx.TEXT_JUSTIFY_LEFT
            );
        }
    }

    // ── Arc value labels ──────────────────────────────────────────────────────

    // Each label is an icon + numeric value placed in a fixed horizontal band
    // (above or below center). The X position follows the arc's midpoint angle;
    // the Y position is clamped to one of two fixed rows so labels don't drift.
    function drawArcLabels(dc, data) {
        // [midDeg, value, color, iconRes, aboveCenter]
        var labels = [
            [45, data[:stress], COLOR_STRESS, Rez.Drawables.IconStress, true],
            [135, data[:kcal], COLOR_KCAL, Rez.Drawables.IconKcal, false],
            [225, data[:body], COLOR_BODY, Rez.Drawables.IconBody, false],
            [315, data[:hr], COLOR_HR, Rez.Drawables.IconHR, true],
        ];

        var timeRenderH = (108.0 * scale).toNumber();
        var valFont = Gfx.FONT_TINY;
        var valFontH = Gfx.getFontHeight(valFont);
        var pad = (20 * scale).toNumber();
        var iconSize = (32.0 * scale).toNumber();
        var gap = (8 * scale).toNumber();

        for (var i = 0; i < labels.size(); i++) {
            var l = labels[i];
            var midDeg = l[0];
            var value = l[1];
            var color = l[2];
            var iconRes = l[3];
            var aboveCenter = l[4];

            var lx = polar(cx, cy, labelRadius, midDeg)[0];
            var dir = aboveCenter ? -1 : 1; // -1 = up, 1 = down from center
            var rowY =
                cy +
                dir * (timeRenderH / 2 + pad + valFontH / 2) -
                valFontH / 2;

            var valStr = value.format("%d");
            var valW = dc.getTextWidthInPixels(valStr, valFont);
            var rowX = lx - (iconSize + gap + valW) / 2;

            var icon = WatchUi.loadResource(iconRes);
            drawScaledBitmap(
                dc,
                icon,
                rowX,
                rowY + (valFontH - iconSize) / 2,
                iconSize,
                iconSize
            );

            dc.setColor(color, Gfx.COLOR_TRANSPARENT);
            dc.drawText(
                rowX + iconSize + gap,
                rowY,
                valFont,
                valStr,
                Gfx.TEXT_JUSTIFY_LEFT
            );
        }
    }

    // ── Geometry ──────────────────────────────────────────────────────────────

    // Converts design-angle polar coordinates to screen (x, y).
    // Design convention: 0° = top, clockwise positive (matches clock face intuition).
    function polar(ox, oy, r, angleDesign) {
        var rad = ((angleDesign - 90) * Math.PI) / 180.0;
        return [
            (ox + r * Math.cos(rad)).toNumber(),
            (oy + r * Math.sin(rad)).toNumber(),
        ];
    }
}
