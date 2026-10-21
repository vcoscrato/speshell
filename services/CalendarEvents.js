.pragma library

// Turns what Dux Calendar's daemon (dcal) answers into the events Speshell shows, and
// what the event form holds into what dcal takes. dcal sends times in UTC, all-day
// events as UTC midnights of their dates, and each occurrence of a repeating event on
// its own, sharing the series' id.

// Meeting and event links come from whoever sent the invitation: only https opens.
function safeUrl(text) {
    return typeof text === "string" && /^https:\/\/[^\s"'<>]+$/.test(text) ? text : "";
}

// A meeting link in what an invitation says, for one dcal doesn't name: Meet, Zoom,
// Teams, Webex, Jitsi, or Whereby.
function meetingLink(text) {
    var match = String(text || "").match(/https:\/\/(?:meet\.google\.com|(?:[\w-]+\.)?zoom\.us|teams\.(?:microsoft|live)\.com|[\w-]+\.webex\.com|meet\.jit\.si|whereby\.com)\/[^\s"'<>)\]]*/i);
    return match ? safeUrl(match[0]) : "";
}

function pad(value) {
    return (value < 10 ? "0" : "") + value;
}

// "2026-10-21": a day as the calendar keys it, in local time.
function dateKey(date) {
    return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate());
}

// A time as dcal takes it, in local time with its offset: "2026-10-21T14:30:00-03:00".
function rfc3339(date) {
    var offset = -date.getTimezoneOffset();
    var sign = offset < 0 ? "-" : "+";
    offset = Math.abs(offset);
    return dateKey(date) + "T" + pad(date.getHours()) + ":" + pad(date.getMinutes()) + ":" + pad(date.getSeconds())
        + sign + pad(Math.floor(offset / 60)) + ":" + pad(offset % 60);
}

// An all-day event's date, sent as the UTC midnight that starts it, as local midnight.
function allDayDate(text) {
    var date = new Date(text);
    return new Date(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
}

// What Speshell knows of each calendar, by id, from dcal's calendars.list: its name,
// color, whether it can be written, and whose it is, to tell a declined invitation.
function calendarsById(calendars) {
    var byId = {};
    for (var i = 0; i < (calendars || []).length; i++) {
        var calendar = calendars[i];
        var personal = calendar.accountKind === "google" || calendar.accountKind === "microsoft";
        byId[calendar.id] = {
            id: calendar.id,
            name: String(calendar.name || calendar.providerName || ""),
            account: String(calendar.accountName || ""),
            color: /^#[0-9a-fA-F]{6}$/.test(String(calendar.color)) ? calendar.color : "",
            readOnly: calendar.readOnly === true,
            hidden: calendar.hidden === true,
            self: personal ? String(calendar.accountId || "").toLowerCase() : ""
        };
    }
    return byId;
}

function declinedBy(raw, self) {
    if (self === "")
        return false;
    var attendees = Array.isArray(raw.attendees) ? raw.attendees : [];
    for (var i = 0; i < attendees.length; i++) {
        var email = String(attendees[i].email || "").toLowerCase().replace(/^mailto:/, "");
        if (email === self)
            return String(attendees[i].status || "").toLowerCase() === "declined";
    }
    return false;
}

// One occurrence from events.list, or null for one Speshell doesn't show.
function event(raw, calendars) {
    if (!raw || typeof raw !== "object" || raw.status === "cancelled")
        return null;
    var calendar = calendars[raw.calendarId] || null;
    if (calendar && calendar.hidden)
        return null;
    var allDay = raw.allDay === true;
    var start = allDay ? allDayDate(raw.start).getTime() : Date.parse(raw.start);
    var end = allDay ? allDayDate(raw.end).getTime() : Date.parse(raw.end);
    if (isNaN(start))
        return null;
    if (isNaN(end) || end < start)
        end = start;
    var rrule = raw.recurrence && Array.isArray(raw.recurrence.rrule) ? raw.recurrence.rrule : [];
    var title = String(raw.summary || "").trim();
    return {
        key: raw.id + "@" + raw.start,
        id: String(raw.id),
        calendarId: String(raw.calendarId || ""),
        calendarName: calendar ? calendar.name : "",
        color: calendar ? calendar.color : "",
        readOnly: !calendar || calendar.readOnly,
        title: title !== "" ? title : (raw.visibility === "private" ? "Busy" : "(No title)"),
        location: String(raw.location || "").trim(),
        start: start,
        end: end,
        allDay: allDay,
        // The occurrence's start as dcal named it, to delete just this one.
        occurrence: String(raw.start),
        recurring: rrule.length > 0 || String(raw.recurringId || "") !== "",
        meetingUrl: safeUrl(raw.meetingUrl) || meetingLink(raw.location) || meetingLink(raw.description),
        url: safeUrl(raw.url),
        declined: declinedBy(raw, calendar ? calendar.self : "")
    };
}

function events(rawEvents, calendars) {
    return (rawEvents || []).map(function(raw) { return event(raw, calendars); })
        .filter(function(item) { return item !== null; });
}

// The events by the local days they cover (yyyy-MM-dd), each day's all-day events
// first, then by start. One that ends at midnight stays off the next day.
function byDay(list) {
    var days = {};
    for (var i = 0; i < list.length; i++) {
        var item = list[i];
        var day = new Date(item.start);
        day.setHours(0, 0, 0, 0);
        var last = item.end > item.start ? item.end - 1 : item.start;
        for (var count = 0; day.getTime() <= last && count < 62; count++) {
            var key = dateKey(day);
            (days[key] = days[key] || []).push(item);
            day.setDate(day.getDate() + 1);
        }
    }
    for (var dayKey in days) {
        days[dayKey].sort(function(a, b) {
            return a.allDay !== b.allDay ? (a.allDay ? -1 : 1)
                : a.start !== b.start ? a.start - b.start
                : a.title.localeCompare(b.title);
        });
    }
    return days;
}

// Minutes past midnight in a typed time, or -1: "9", "09:30", "930", "14h30",
// "2pm", "2:30 pm", "12am".
function parseTime(text) {
    var match = String(text || "").trim().toLowerCase()
        .match(/^(\d{1,2})(?:[:.h]?(\d{2}))?\s*(am?|pm?)?$/);
    if (!match)
        return -1;
    var hours = Number(match[1]);
    var minutes = match[2] ? Number(match[2]) : 0;
    if (minutes > 59)
        return -1;
    if (match[3]) {
        if (hours < 1 || hours > 12)
            return -1;
        hours = hours % 12 + (match[3].charAt(0) === "p" ? 12 : 0);
    } else if (hours > 23) {
        return -1;
    }
    return hours * 60 + minutes;
}

// How many days after its start day an event ends: for an all-day one, the day after
// its last; 0 for one that ends the day it starts.
function endDays(item) {
    var first = new Date(item.start);
    var last = new Date(item.end > item.start && !item.allDay ? item.end - 1 : item.end);
    var days = Math.round((new Date(last.getFullYear(), last.getMonth(), last.getDate())
        - new Date(first.getFullYear(), first.getMonth(), first.getDate())) / 86400000);
    return item.allDay ? Math.max(1, days) : Math.max(0, days);
}

// dcal's params for the form's draft: { title, day (Date), allDay, startText, endText,
// endDays, location, calendarId }, or { error } when its times don't make sense. A
// missing end is an hour after the start, and an end before the start on the same
// day runs past midnight.
function params(draft) {
    var day = new Date(draft.day.getFullYear(), draft.day.getMonth(), draft.day.getDate());
    var days = Math.max(0, Math.round(Number(draft.endDays) || 0));
    var start;
    var end;
    if (draft.allDay) {
        start = day;
        end = new Date(day.getFullYear(), day.getMonth(), day.getDate() + Math.max(1, days));
    } else {
        var from = parseTime(draft.startText);
        if (from < 0)
            return { error: "Start at a time like 9:30, 14:00, or 2pm." };
        var to = String(draft.endText || "").trim() === "" ? from + 60 : parseTime(draft.endText);
        if (to < 0)
            return { error: "End at a time like 10:30, 15:00, or 3pm." };
        to += days * 24 * 60;
        if (to <= from)
            to += 24 * 60;
        start = new Date(day.getFullYear(), day.getMonth(), day.getDate(), 0, from);
        end = new Date(day.getFullYear(), day.getMonth(), day.getDate(), 0, to);
    }
    return {
        calendarId: draft.calendarId,
        summary: String(draft.title || "").trim(),
        location: String(draft.location || "").trim(),
        allDay: draft.allDay === true,
        start: rfc3339(start),
        end: rfc3339(end)
    };
}
