using Toybox.Lang;
using Toybox.Test;

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
