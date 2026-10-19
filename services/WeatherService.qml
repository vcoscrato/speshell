pragma Singleton
import QtQuick
import Quickshell

// The weather at [Weather] location, or where the IP address places this machine when
// it's empty, from Open-Meteo: the current conditions, the next hours, and the next
// days. Units follow the locale's measurement system.
Singleton {
    id: root

    readonly property bool enabled: ConfigService.settings.weather.enabled
    readonly property string location: ConfigService.settings.weather.location

    // "", "loading", "ready", "offline" (no answer; retried soon), or "unknown" (no
    // place by that name).
    property string status: ""
    readonly property bool ready: root.status === "ready"
    // The place the forecast is for, as "City, Region".
    property string place: ""
    // { temperature, apparent, humidity, wind, code, day, condition, icon }
    property var current: ({ temperature: 0, apparent: 0, humidity: 0, wind: 0, code: 0, day: true, condition: "", icon: "weather-cloudy" })
    // The next 24 hours from the current one: { time (Date), temperature, code, day, icon, rain }
    property var hours: []
    // Today and the next days: { date (Date), high, low, code, icon, condition, rain, sunrise, sunset }
    property var days: []
    property double fetchedAt: 0

    readonly property bool imperial: Qt.locale().measurementSystem === Locale.ImperialUSSystem
    readonly property string windUnit: root.imperial ? "mph" : "km/h"
    readonly property string summary: root.ready
        ? [root.current.condition, root.temperatureText(root.current.temperature), root.place].filter(Boolean).join(" · ")
        : ""

    // Coordinates for root.location, kept until it changes: { latitude, longitude, place }.
    property var spot: null
    property int requestId: 0

    // WMO weather codes: a condition and the kind of sky its icon shows.
    readonly property var conditions: ({
        0: ["Clear", "clear"], 1: ["Mainly clear", "partly"], 2: ["Partly cloudy", "partly"], 3: ["Overcast", "cloudy"],
        45: ["Fog", "fog"], 48: ["Freezing fog", "fog"],
        51: ["Light drizzle", "rain"], 53: ["Drizzle", "rain"], 55: ["Heavy drizzle", "rain"],
        56: ["Freezing drizzle", "rain"], 57: ["Freezing drizzle", "rain"],
        61: ["Light rain", "rain"], 63: ["Rain", "rain"], 65: ["Heavy rain", "rain"],
        66: ["Freezing rain", "rain"], 67: ["Freezing rain", "rain"],
        71: ["Light snow", "snow"], 73: ["Snow", "snow"], 75: ["Heavy snow", "snow"], 77: ["Snow grains", "snow"],
        80: ["Light showers", "rain"], 81: ["Showers", "rain"], 82: ["Heavy showers", "rain"],
        85: ["Snow showers", "snow"], 86: ["Heavy snow showers", "snow"],
        95: ["Thunderstorm", "storm"], 96: ["Thunderstorm with hail", "storm"], 99: ["Thunderstorm with hail", "storm"]
    })

    function condition(code) {
        return (root.conditions[code] || ["Unknown", "cloudy"])[0];
    }

    function icon(code, day) {
        const sky = (root.conditions[code] || ["", "cloudy"])[1];
        if (sky === "clear")
            return day ? "weather-clear" : "weather-night";
        if (sky === "partly")
            return day ? "weather-partly" : "weather-partly-night";
        return "weather-" + sky;
    }

    // "24°"
    function temperatureText(value) {
        return Math.round(value) + "°";
    }

    function get(url, onDone) {
        const id = root.requestId;
        const request = new XMLHttpRequest();
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE || id !== root.requestId)
                return;
            let body = null;
            try {
                body = request.status === 200 ? JSON.parse(request.responseText) : null;
            } catch (error) {
                body = null;
            }
            onDone(body);
        };
        request.open("GET", url);
        request.send();
    }

    // Fetches the forecast, finding the location's coordinates first if needed.
    function refresh() {
        if (!root.enabled)
            return;
        root.requestId++;
        if (root.status !== "ready")
            root.status = "loading";
        if (root.spot) {
            root.fetchForecast();
            return;
        }
        const name = root.location.trim();
        if (name === "") {
            root.get("https://ipinfo.io/json", function(body) {
                const coordinates = body && body.loc ? String(body.loc).split(",").map(Number) : [];
                if (coordinates.length !== 2 || coordinates.some(isNaN))
                    return root.fail("offline");
                root.spot = {
                    latitude: coordinates[0],
                    longitude: coordinates[1],
                    place: [body.city, body.region].filter(Boolean).join(", ")
                };
                root.fetchForecast();
            });
            return;
        }
        root.get("https://geocoding-api.open-meteo.com/v1/search?count=1&format=json&language=en&name="
                + encodeURIComponent(name), function(body) {
            if (!body)
                return root.fail("offline");
            const found = (body.results || [])[0];
            if (!found)
                return root.fail("unknown");
            root.spot = {
                latitude: found.latitude,
                longitude: found.longitude,
                place: [found.name, found.admin1].filter(Boolean).join(", ")
            };
            root.fetchForecast();
        });
    }

    function fetchForecast() {
        const spot = root.spot;
        const url = "https://api.open-meteo.com/v1/forecast?timezone=auto&timeformat=unixtime&forecast_days=7&forecast_hours=24"
            + "&latitude=" + spot.latitude + "&longitude=" + spot.longitude
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
            + "&hourly=temperature_2m,weather_code,precipitation_probability,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"
            + (root.imperial ? "&temperature_unit=fahrenheit&wind_speed_unit=mph" : "");
        root.get(url, function(body) {
            if (!body || !body.current || !body.hourly || !body.daily)
                return root.fail("offline");
            root.apply(body, spot.place);
        });
    }

    // Times come as Unix seconds; days start at the place's midnight, so a day's date
    // is read in the place's own time.
    function apply(body, place) {
        const offset = body.utc_offset_seconds || 0;
        const placeDate = seconds => {
            const shifted = new Date((seconds + offset) * 1000);
            return new Date(shifted.getUTCFullYear(), shifted.getUTCMonth(), shifted.getUTCDate());
        };
        const now = body.current;
        root.current = {
            temperature: now.temperature_2m,
            apparent: now.apparent_temperature,
            humidity: now.relative_humidity_2m,
            wind: now.wind_speed_10m,
            code: now.weather_code,
            day: now.is_day === 1,
            condition: root.condition(now.weather_code),
            icon: root.icon(now.weather_code, now.is_day === 1)
        };
        const hourly = body.hourly;
        root.hours = hourly.time.map((time, i) => ({
            time: new Date(time * 1000),
            temperature: hourly.temperature_2m[i],
            code: hourly.weather_code[i],
            day: hourly.is_day[i] === 1,
            icon: root.icon(hourly.weather_code[i], hourly.is_day[i] === 1),
            rain: hourly.precipitation_probability[i] ?? 0
        }));
        const daily = body.daily;
        root.days = daily.time.map((date, i) => ({
            date: placeDate(date),
            high: daily.temperature_2m_max[i],
            low: daily.temperature_2m_min[i],
            code: daily.weather_code[i],
            icon: root.icon(daily.weather_code[i], true),
            condition: root.condition(daily.weather_code[i]),
            rain: daily.precipitation_probability_max[i] ?? 0,
            sunrise: new Date(daily.sunrise[i] * 1000),
            sunset: new Date(daily.sunset[i] * 1000)
        }));
        root.place = place;
        root.fetchedAt = Date.now();
        root.status = "ready";
        retryTimer.stop();
    }

    // A failed lookup, often no network yet at login, retries sooner than the regular
    // refresh. A reading already shown stays through a failed refresh.
    function fail(reason) {
        if (root.status !== "ready")
            root.status = reason;
        if (reason === "offline")
            retryTimer.restart();
    }

    // Refreshes a reading older than a quarter hour, as after waking from sleep.
    function refreshIfStale() {
        if (root.enabled && Date.now() - root.fetchedAt > 15 * 60 * 1000)
            root.refresh();
    }

    function reset() {
        root.requestId++;
        root.spot = null;
        root.status = "";
        root.place = "";
        root.hours = [];
        root.days = [];
        root.fetchedAt = 0;
        retryTimer.stop();
    }

    onLocationChanged: {
        root.reset();
        root.refresh();
    }

    onEnabledChanged: {
        root.reset();
        root.refresh();
    }

    Timer {
        interval: 30 * 60 * 1000
        running: root.enabled
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: retryTimer
        interval: 2 * 60 * 1000
        onTriggered: root.refresh()
    }
}
