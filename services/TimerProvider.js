.pragma library

// The timer in the launcher (`!timer`), and its lengths as typed and shown.

var presets = [5, 15, 25, 45];
var longest = 24 * 3600;

var unitSeconds = { h: 3600, m: 60, s: 1 };

// Seconds in `text`, or 0 when it isn't a length up to a day: hours, minutes, and
// seconds in that order ("1h30m", "1h 30", "90s", "2 min"), where a bare number is
// minutes, or the next smaller unit after one.
function parseDuration(text) {
    var rest = String(text || "").trim().toLowerCase();
    var token = /^(\d+(?:[.,]\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)?\s*/;
    var order = ["h", "m", "s"];
    // The smallest unit the next part may have; a bare first number is minutes.
    var next = 0;
    var total = 0;
    if (rest === "")
        return 0;
    while (rest !== "") {
        var match = token.exec(rest);
        if (!match)
            return 0;
        var rank = match[2] ? order.indexOf(match[2].charAt(0)) : Math.max(next, 1);
        if (rank < next || rank >= order.length)
            return 0;
        total += parseFloat(match[1].replace(",", ".")) * unitSeconds[order[rank]];
        next = rank + 1;
        rest = rest.substring(match[0].length);
    }
    total = Math.round(total);
    return total > 0 && total <= longest ? total : 0;
}

// "1 h 30 min", "25 min", "45 s".
function formatLength(seconds) {
    var hours = Math.floor(seconds / 3600);
    var minutes = Math.floor(seconds % 3600 / 60);
    var rest = seconds % 60;
    var parts = [];
    if (hours > 0)
        parts.push(hours + " h");
    if (minutes > 0)
        parts.push(minutes + " min");
    if (rest > 0 || parts.length === 0)
        parts.push(rest + " s");
    return parts.join(" ");
}

// "4:05", or "1:02:03" past an hour.
function formatClock(seconds) {
    var hours = Math.floor(seconds / 3600);
    var minutes = Math.floor(seconds % 3600 / 60);
    var rest = seconds % 60;
    var pad = function(value) { return (value < 10 ? "0" : "") + value; };
    return (hours > 0 ? hours + ":" + pad(minutes) : String(minutes)) + ":" + pad(rest);
}

function result(id, title, subtitle, iconName, payload) {
    return {
        id: "timer:" + id,
        kind: "timer",
        title: title,
        subtitle: subtitle,
        iconName: iconName,
        iconSource: "",
        badge: "TIMER",
        activatable: true,
        payload: payload
    };
}

// Where a running timer stands: "Ends at 14:32", or "Paused · 12:34 left".
function standing(state) {
    return state.paused
        ? "Paused · " + formatClock(state.remaining) + " left"
        : "Ends at " + Qt.formatTime(new Date(state.endsAt), "HH:mm");
}

// The `!timer` bang's results for what follows it, given the timer's `state`
// ({ running, paused, remaining, endsAt }): a typed length starts or extends it;
// nothing offers the presets, or controls a running timer.
function timerResults(terms, state) {
    var text = String(terms || "").trim();
    var running = state && state.running;
    if (text !== "") {
        var seconds = parseDuration(text);
        if (seconds === 0) {
            return [{
                id: "timer:invalid",
                kind: "error",
                title: "Not a length",
                subtitle: "Type minutes, or a length like 1h30 or 90s",
                iconName: "timer",
                iconSource: "",
                badge: "TIMER",
                activatable: false,
                payload: ({})
            }];
        }
        var length = formatLength(seconds);
        var start = result("start:" + seconds, "Start a timer for " + length,
            running ? "Replaces the running timer" : "Notifies you when it ends", "timer",
            { action: "start", seconds: seconds });
        return running
            ? [result("add:" + seconds, "Add " + length, standing(state), "plus", { action: "add", seconds: seconds }), start]
            : [start];
    }
    if (running) {
        return [
            state.paused
                ? result("resume", "Resume the timer", standing(state), "media-play", { action: "resume" })
                : result("pause", "Pause the timer", standing(state), "media-pause", { action: "pause" }),
            result("add:300", "Add 5 min", standing(state), "plus", { action: "add", seconds: 300 }),
            result("stop", "Stop the timer", standing(state), "close", { action: "stop" })
        ];
    }
    return presets.map(function(minutes) {
        return result("start:" + minutes * 60, "Start a timer for " + minutes + " min",
            "Or type a length, like 1h30 or 90s", "timer", { action: "start", seconds: minutes * 60 });
    });
}

// The `!timer` suggestion while typing a bang, and the launcher's "Timer" item.
function suggestion() {
    return {
        id: "timer:browse",
        kind: "timer",
        title: "Timer",
        subtitle: "Start, pause, or stop a timer · Tab to complete",
        iconName: "timer",
        iconSource: "",
        badge: "TIMER",
        activatable: true,
        payload: ({}),
        completion: "!timer ",
        completeOnActivate: true,
        bang: "timer",
        keywords: "countdown alarm pomodoro focus"
    };
}

// What follows `!timer` in `query`, or null when the query isn't that bang.
function parseBang(query) {
    var match = /^!timer(?:\s+(.*))?$/i.exec(String(query || "").trim());
    return match ? (match[1] || "") : null;
}
