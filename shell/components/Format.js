.pragma library

// How Speshell writes times and lengths of time.

// "4:05", or "1:02:03" past an hour: a countdown, an elapsed time, a track's position.
function clock(seconds) {
    const total = Math.max(0, Math.floor(Number(seconds) || 0));
    const hours = Math.floor(total / 3600);
    const minutes = Math.floor(total % 3600 / 60);
    const rest = total % 60;
    const pad = value => (value < 10 ? "0" : "") + value;
    return (hours > 0 ? hours + ":" + pad(minutes) : String(minutes)) + ":" + pad(rest);
}

// "1 h 30 min", "25 min", "45 s": a length of time in words.
function duration(seconds) {
    const total = Math.max(0, Math.round(Number(seconds) || 0));
    const hours = Math.floor(total / 3600);
    const minutes = Math.floor(total % 3600 / 60);
    const rest = total % 60;
    const parts = [];
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

// "Friday, 31 October": a day.
function date(day) {
    return Qt.formatDate(day, "dddd, d MMMM");
}

// "October 2026": a month.
function month(day) {
    return Qt.formatDate(day, "MMMM yyyy");
}

// "Fri": a day of the week.
function weekday(day) {
    return Qt.formatDate(day, "ddd");
}

// "Fri 31 Oct": a day, where room is short.
function shortDate(day) {
    return Qt.formatDate(day, "ddd d MMM");
}

// "just now", "5 min ago", "3 h ago", "2 d ago": how long before `nowMs` the time
// `then` (a Date or ms) was.
function ago(then, nowMs) {
    const seconds = Math.floor((nowMs - Number(then)) / 1000);
    if (seconds < 60)
        return "just now";
    if (seconds < 3600)
        return Math.floor(seconds / 60) + " min ago";
    if (seconds < 86400)
        return Math.floor(seconds / 3600) + " h ago";
    return Math.floor(seconds / 86400) + " d ago";
}
