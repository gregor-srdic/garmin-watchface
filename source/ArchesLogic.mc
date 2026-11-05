using Toybox.ActivityMonitor;
using Toybox.Complications;
using Toybox.Lang;
using Toybox.Math;

// Pure helpers used by the view. Kept free of drawing code so they can be
// unit-tested (see test/ArchesLogicTest.mc).
module ArchesLogic {
    // Reads a complication, or returns null when the device doesn't provide
    // this type. getComplication throws ComplicationNotFoundException rather
    // than returning null, which would otherwise crash the face.
    function safeGetComplication(id as Complications.Id?) as Complications.Complication? {
        if (id == null) {
            return null;
        }
        try {
            return Complications.getComplication(id);
        } catch (e) {
            return null;
        }
    }

    // The value shown for a slot, or null when there is no data. Calories
    // prefer ActivityMonitor (total incl. resting) over the complication value.
    function slotValue(comp as Complications.Complication?) as Lang.Number? {
        if (comp == null || comp.value == null) {
            return null;
        }
        var value = (comp.value as Lang.Numeric).toNumber();
        if (comp.getType() == Complications.COMPLICATION_TYPE_CALORIES) {
            var info = ActivityMonitor.getInfo();
            if (info.calories != null) {
                value = info.calories;
            }
        }
        return value;
    }

    // Returns [value, max] for an arc slot. value is 0 when there is no data.
    function slotReading(comp as Complications.Complication?) as Lang.Array<Lang.Number> {
        var value = slotValue(comp);
        if (value == null) {
            return [0, 100];
        }
        return [value, compMax(comp.getType())];
    }

    // Full-scale arc value for the complication types the face uses.
    function compMax(type) as Lang.Number {
        if (type == Complications.COMPLICATION_TYPE_HEART_RATE) {
            return 200;
        }
        if (type == Complications.COMPLICATION_TYPE_CALORIES) {
            return 5000;
        }
        return 100; // stress, body battery
    }

    // Two-character hour string for the bitmap digits. 12-hour mode keeps the
    // leading zero ("05") because the layout has a fixed four-digit width.
    function hourString(hour as Lang.Number, is24Hour as Lang.Boolean) as Lang.String {
        if (!is24Hour) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }
        return hour.format("%02d");
    }

    // Converts a Celsius reading to the user's unit, rounded to a whole degree.
    // Round after converting, so 21.6 C shows as 71 F rather than 69 F.
    function displayTemp(celsius as Lang.Numeric, statute as Lang.Boolean) as Lang.Number {
        var t = celsius.toFloat();
        if (statute) {
            t = t * 9.0 / 5.0 + 32.0;
        }
        return Math.round(t).toNumber();
    }
}
