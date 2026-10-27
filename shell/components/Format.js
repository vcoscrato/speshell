.pragma library

// How Speshell writes times and lengths of time.

// "4:05", or "1:02:03" past an hour: a countdown, an elapsed time, a track's position.
function clock(seconds) {
    var total = Math.max(0, Math.floor(Number(seconds) || 0));
    var hours = Math.floor(total / 3600);
    var minutes = Math.floor(total % 3600 / 60);
    var rest = total % 60;
    var pad = function(value) { return (value < 10 ? "0" : "") + value; };
    return (hours > 0 ? hours + ":" + pad(minutes) : String(minutes)) + ":" + pad(rest);
}

// "1 h 30 min", "25 min", "45 s": a length of time in words.
function duration(seconds) {
    var total = Math.max(0, Math.round(Number(seconds) || 0));
    var hours = Math.floor(total / 3600);
    var minutes = Math.floor(total % 3600 / 60);
    var rest = total % 60;
    var parts = [];
    if (hours > 0)
        parts.push(hours + " h");
    if (minutes > 0)
        parts.push(minutes + " min");
    if (rest > 0 || parts.length === 0)
        parts.push(rest + " s");
    return parts.join(" ");
}

// "21:30": a time of day.
function time(date) {
    return Qt.formatTime(date, "HH:mm");
}

// "just now", "5 min ago", "3 h ago", "2 d ago": how long before `nowMs` the time
// `then` (a Date or ms) was.
function ago(then, nowMs) {
    var seconds = Math.floor((nowMs - Number(then)) / 1000);
    if (seconds < 60)
        return "just now";
    if (seconds < 3600)
        return Math.floor(seconds / 60) + " min ago";
    if (seconds < 86400)
        return Math.floor(seconds / 3600) + " h ago";
    return Math.floor(seconds / 86400) + " d ago";
}
