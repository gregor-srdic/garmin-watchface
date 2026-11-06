using Toybox.Lang;
using Toybox.Test;
using Toybox.Weather;

// Run: build with `monkeyc -t`, then `monkeydo <prg> fr965 /t` with the simulator open.

// Bug 1: an empty slot (null complication) must not crash the arc drawing.
(:test)
function slotReadingHandlesNullComplication(logger as Test.Logger) as Lang.Boolean {
    var r = ArchesLogic.slotReading(null);
    Test.assertEqual(r[0], 0);
    Test.assertEqual(r[1], 100);
    return true;
}

// Bug 3: 12-hour devices must not show 24-hour time.
(:test)
function hourStringAfternoonIn12h(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.hourString(17, false), "05");
    return true;
}

(:test)
function hourStringMidnightIn12h(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.hourString(0, false), "12");
    return true;
}

(:test)
function hourStringNoonIn12h(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.hourString(12, false), "12");
    return true;
}

(:test)
function hourStringUnchangedIn24h(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.hourString(0, true), "00");
    Test.assertEqual(ArchesLogic.hourString(17, true), "17");
    return true;
}

// Bug 5: convert first, then round. 21.6 C = 70.88 F -> 71.
(:test)
function displayTempRoundsAfterConverting(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.displayTemp(21.6, true), 71);
    return true;
}

// -1.0 C = 30.2 F -> 30 (integer division used to give 31).
(:test)
function displayTempNegativeToFahrenheit(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.displayTemp(-1.0, true), 30);
    return true;
}

(:test)
function displayTempCelsiusRounds(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.displayTemp(21.6, false), 22);
    return true;
}

// --- AM/PM label (12-hour mode) ---
(:test)
function ampmLabelMorning(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.ampmLabel(0), "AM");
    Test.assertEqual(ArchesLogic.ampmLabel(11), "AM");
    return true;
}

(:test)
function ampmLabelAfternoon(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.ampmLabel(12), "PM");
    Test.assertEqual(ArchesLogic.ampmLabel(23), "PM");
    return true;
}

// --- Night detection (seconds since epoch; sunrise 06:30, sunset 19:45 on a day) ---
(:test)
function isNightUsesSunriseSunset(logger as Test.Logger) as Lang.Boolean {
    var sunrise = 1000000 + 6 * 3600 + 1800;
    var sunset = 1000000 + 19 * 3600 + 2700;
    Test.assert(ArchesLogic.isNight(sunrise - 1, sunrise, sunset, 6));
    Test.assert(!ArchesLogic.isNight(sunrise, sunrise, sunset, 6));
    Test.assert(!ArchesLogic.isNight(sunset - 1, sunrise, sunset, 19));
    Test.assert(ArchesLogic.isNight(sunset, sunrise, sunset, 19));
    return true;
}

(:test)
function isNightFallsBackToFixedHours(logger as Test.Logger) as Lang.Boolean {
    Test.assert(ArchesLogic.isNight(0, null, null, 5));
    Test.assert(!ArchesLogic.isNight(0, null, null, 6));
    Test.assert(!ArchesLogic.isNight(0, null, null, 19));
    Test.assert(ArchesLogic.isNight(0, null, null, 20));
    return true;
}

// --- Weather icon with night variant ---
(:test)
function weatherIconClearDayIsSun(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.weatherIconFor(Weather.CONDITION_CLEAR, false), Rez.Drawables.WeatherSun);
    return true;
}

(:test)
function weatherIconClearNightIsMoon(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.weatherIconFor(Weather.CONDITION_CLEAR, true), Rez.Drawables.WeatherMoon);
    Test.assertEqual(ArchesLogic.weatherIconFor(Weather.CONDITION_THIN_CLOUDS, true), Rez.Drawables.WeatherMoon);
    return true;
}

(:test)
function weatherIconOtherConditionsIgnoreNight(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.weatherIconFor(Weather.CONDITION_CLOUDY, true), Rez.Drawables.WeatherCloud);
    Test.assertEqual(ArchesLogic.weatherIconFor(Weather.CONDITION_RAIN, true), Rez.Drawables.WeatherRain);
    // assertEqual can't take null (it calls .equals on it), so compare directly.
    Test.assert(ArchesLogic.weatherIconFor(-1, false) == null);
    return true;
}

// Visual refresh: single date row and temperature text.
(:test)
function dateRowText24h(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.dateRowText("Mon", "Apr", 27, null), "MON · APR 27");
    return true;
}

(:test)
function dateRowText12h(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.dateRowText("Mon", "Apr", 27, "PM"), "MON · APR 27 · PM");
    return true;
}

(:test)
function dateRowTextUpperCasesInput(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.dateRowText("tue", "may", 3, null), "TUE · MAY 3");
    return true;
}

(:test)
function dateRowTextSingleDigitDay(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.dateRowText("Mon", "Apr", 7, "PM"), "MON · APR 7 · PM");
    return true;
}

(:test)
function tempTextPositive(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.tempText(58), "58°");
    return true;
}

(:test)
function tempTextNegative(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.tempText(-3), "-3°");
    return true;
}

(:test)
function tempTextZero(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.tempText(0), "0°");
    return true;
}

// assertEqual(null, null) is unreliable on device, so compare explicitly.
(:test)
function tempTextNull(logger as Test.Logger) as Lang.Boolean {
    Test.assert(ArchesLogic.tempText(null) == null);
    return true;
}

(:test)
function arcFillEndZero(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.arcFillEnd(5, 85, 0, 100), 5);
    return true;
}

(:test)
function arcFillEndHalf(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.arcFillEnd(5, 85, 50, 100), 45);
    return true;
}

(:test)
function arcFillEndClampsOverMax(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.arcFillEnd(5, 85, 150, 100), 85);
    return true;
}

(:test)
function arcFillEndClampsNegative(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.arcFillEnd(5, 85, -10, 100), 5);
    return true;
}

(:test)
function arcFillEndZeroMax(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.arcFillEnd(5, 85, 10, 0), 5);
    return true;
}

// --- Battery percentage / text / low state ---
(:test)
function batteryPercentRoundsDown(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.batteryPercent(78.4), 78);
    return true;
}

(:test)
function batteryPercentRoundsUp(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.batteryPercent(78.5), 79);
    return true;
}

(:test)
function batteryPercentClampsNegative(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.batteryPercent(-1.0), 0);
    return true;
}

(:test)
function batteryPercentClampsOver100(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.batteryPercent(100.6), 100);
    return true;
}

(:test)
function batteryTextAppendsPercent(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.batteryText(78), "78%");
    return true;
}

(:test)
function batteryTextBounds(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.batteryText(0), "0%");
    Test.assertEqual(ArchesLogic.batteryText(100), "100%");
    return true;
}

(:test)
function isBatteryLowAtThreshold(logger as Test.Logger) as Lang.Boolean {
    Test.assert(ArchesLogic.isBatteryLow(15, false));
    return true;
}

(:test)
function isBatteryLowAboveThreshold(logger as Test.Logger) as Lang.Boolean {
    Test.assert(!ArchesLogic.isBatteryLow(16, false));
    return true;
}

(:test)
function isBatteryLowIgnoredWhileCharging(logger as Test.Logger) as Lang.Boolean {
    Test.assert(!ArchesLogic.isBatteryLow(10, true));
    return true;
}

// --- Touch-and-hold hit testing (centre 227,227) ---
// Exclusions: time-block-like and date/info-row-like rects [left, top, right, bottom].
(:test)
function slotAtTopRightIsSlot0(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.slotAt(350, 100, 227, 227, [[150, 173, 304, 281], [180, 120, 274, 140]]), 0);
    return true;
}

(:test)
function slotAtBottomRightIsSlot1(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.slotAt(350, 350, 227, 227, [[150, 173, 304, 281], [180, 120, 274, 140]]), 1);
    return true;
}

(:test)
function slotAtBottomLeftIsSlot2(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.slotAt(100, 350, 227, 227, [[150, 173, 304, 281], [180, 120, 274, 140]]), 2);
    return true;
}

(:test)
function slotAtTopLeftIsSlot3(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.slotAt(100, 100, 227, 227, [[150, 173, 304, 281], [180, 120, 274, 140]]), 3);
    return true;
}

(:test)
function slotAtInsideTimeBlockIsNull(logger as Test.Logger) as Lang.Boolean {
    var r = ArchesLogic.slotAt(227, 227, 227, 227, [[150, 173, 304, 281], [180, 120, 274, 140]]);
    Test.assert(r == null);
    return true;
}

(:test)
function slotAtInsideRowIsNull(logger as Test.Logger) as Lang.Boolean {
    var r = ArchesLogic.slotAt(200, 130, 227, 227, [[150, 173, 304, 281], [180, 120, 274, 140]]);
    Test.assert(r == null);
    return true;
}

(:test)
function slotAtExclusionEdgesAreInclusive(logger as Test.Logger) as Lang.Boolean {
    var ex = [[150, 173, 304, 281]];
    Test.assert(ArchesLogic.slotAt(150, 173, 227, 227, ex) == null);
    Test.assert(ArchesLogic.slotAt(304, 281, 227, 227, ex) == null);
    return true;
}

// Arc labels sit outside the exclusions and belong to their quadrant.
(:test)
function slotAtArcLabelPositionResolvesToQuadrant(logger as Test.Logger) as Lang.Boolean {
    Test.assertEqual(ArchesLogic.slotAt(320, 160, 227, 227, [[150, 173, 304, 281], [180, 120, 274, 140]]), 0);
    return true;
}

(:test)
function slotAtAxisTieBreaks(logger as Test.Logger) as Lang.Boolean {
    var ex = [[150, 173, 304, 281], [180, 120, 274, 140]];
    Test.assertEqual(ArchesLogic.slotAt(227, 100, 227, 227, ex), 0);
    Test.assertEqual(ArchesLogic.slotAt(100, 227, 227, 227, ex), 2);
    Test.assertEqual(ArchesLogic.slotAt(350, 227, 227, 227, ex), 1);
    return true;
}

(:test)
function slotAtEmptyExclusions(logger as Test.Logger) as Lang.Boolean {
    var ex = [] as Lang.Array<Lang.Array<Lang.Number> >;
    Test.assertEqual(ArchesLogic.slotAt(350, 100, 227, 227, ex), 0);
    Test.assertEqual(ArchesLogic.slotAt(227, 227, 227, 227, ex), 1);
    return true;
}
