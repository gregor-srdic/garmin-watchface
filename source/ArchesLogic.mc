using Toybox.ActivityMonitor;
using Toybox.Complications;
using Toybox.Lang;
using Toybox.Math;
using Toybox.Weather;

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

    // "AM" for 00:00-11:59, "PM" for 12:00-23:59.
    function ampmLabel(hour as Lang.Number) as Lang.String {
        return hour < 12 ? "AM" : "PM";
    }

    // True before sunrise or from sunset on (times in seconds since epoch).
    // Without sunrise/sunset data, night is 20:00-06:00 local time.
    function isNight(
        now as Lang.Number,
        sunrise as Lang.Number?,
        sunset as Lang.Number?,
        hour as Lang.Number
    ) as Lang.Boolean {
        if (sunrise == null || sunset == null) {
            return hour < 6 || hour >= 20;
        }
        return now < sunrise || now >= sunset;
    }

    // Maps a Weather condition code to a drawable resource ID, or null if
    // unknown. Clear-sky conditions show a moon instead of the sun at night.
    function weatherIconFor(c as Lang.Number, night as Lang.Boolean) as Lang.ResourceId? {
        if (
            c == Weather.CONDITION_CLEAR ||
            c == Weather.CONDITION_FAIR ||
            c == Weather.CONDITION_MOSTLY_CLEAR ||
            c == Weather.CONDITION_PARTLY_CLEAR ||
            c == Weather.CONDITION_THIN_CLOUDS
        ) {
            return night ? Rez.Drawables.WeatherMoon : Rez.Drawables.WeatherSun;
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
}
