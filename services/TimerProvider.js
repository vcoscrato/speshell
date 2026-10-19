.pragma library

// Timer lengths as typed and shown.

var presets = [5, 10, 25, 45];
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

// A length and a name, as the timer panel and `speshell timer` take them: the length
// before or after the name ("10 pasta", "tea 4m", "1h30"), or the time it ends ("bread at
// 21:30", "at 7"), from `now` (ms). `seconds` is 0, and the whole text the name, when
// no length is there.
function parseTimer(text, now) {
    var trimmed = String(text || "").trim().replace(/\s+/g, " ");
    var at = /(?:^| )(?:at|until) (\d{1,2})(?:[:h.](\d{2}))?(?= |$)/i.exec(trimmed);
    if (at) {
        var hours = parseInt(at[1], 10);
        var minutes = at[2] ? parseInt(at[2], 10) : 0;
        if (hours < 24 && minutes < 60) {
            var start = new Date(now === undefined ? Date.now() : now);
            var end = new Date(start.getTime());
            end.setHours(hours, minutes, 0, 0);
            if (end <= start)
                end.setDate(end.getDate() + 1);
            return {
                seconds: Math.round((end - start) / 1000),
                name: (trimmed.slice(0, at.index) + " " + trimmed.slice(at.index + at[0].length)).trim()
            };
        }
    }
    var words = trimmed === "" ? [] : trimmed.split(" ");
    for (var count = words.length; count > 0; count--) {
        var leading = parseDuration(words.slice(0, count).join(" "));
        if (leading > 0)
            return { seconds: leading, name: words.slice(count).join(" ") };
        var trailing = parseDuration(words.slice(words.length - count).join(" "));
        if (trailing > 0)
            return { seconds: trailing, name: words.slice(0, words.length - count).join(" ") };
    }
    return { seconds: 0, name: trimmed };
}
