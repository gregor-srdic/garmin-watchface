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
