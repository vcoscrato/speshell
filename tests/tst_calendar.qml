import QtQuick
import QtTest
import "../services/CalendarEvents.js" as CalendarEvents

TestCase {
    name: "Calendar"

    // As dcal's calendars.list and events.list answer.
    readonly property var calendars: CalendarEvents.calendarsById([
        { id: "work", name: "Work", color: "#4285f4", accountId: "Me@Example.com", accountKind: "google", readOnly: false },
        { id: "holidays", name: "Holidays", color: "", accountId: "me@example.com", accountKind: "google", readOnly: true },
        { id: "muted", name: "Muted", hidden: true, accountKind: "local" }
    ])

    function raw(fields) {
        return Object.assign({
            id: "e1", uid: "u1", calendarId: "work", summary: "Review", location: "", description: "",
            start: "2026-10-21T17:00:00Z", end: "2026-10-21T18:00:00Z", allDay: false,
            status: "confirmed", recurringId: "", url: "", meetingUrl: "", visibility: ""
        }, fields);
    }

    function one(fields) {
        return CalendarEvents.event(raw(fields), calendars);
    }

    function test_readsAnEvent() {
        const item = one({ meetingUrl: "https://meet.google.com/abc", url: "https://www.google.com/calendar/event?eid=x" });
        compare(item.title, "Review");
        compare(item.start, Date.parse("2026-10-21T17:00:00Z"));
        compare(item.calendarName, "Work");
        compare(item.color, "#4285f4");
        compare(item.readOnly, false);
        compare(item.recurring, false);
        compare(item.meetingUrl, "https://meet.google.com/abc");
        compare(item.key, "e1@2026-10-21T17:00:00Z");
    }

    function test_keepsAllDayEventsOnTheirDate() {
        // The UTC midnight that dcal sends is the previous evening west of Greenwich.
        const item = one({ allDay: true, start: "2026-10-23T00:00:00Z", end: "2026-10-24T00:00:00Z" });
        compare(CalendarEvents.dateKey(new Date(item.start)), "2026-10-23");
        compare(Object.keys(CalendarEvents.byDay([item])), ["2026-10-23"]);
    }

    function test_spreadsAnEventOverTheDaysItCovers() {
        const start = new Date(2026, 9, 25, 18, 0);
        const item = one({ start: start.toISOString(), end: new Date(2026, 9, 27, 10, 0).toISOString() });
        compare(Object.keys(CalendarEvents.byDay([item])).sort(), ["2026-10-25", "2026-10-26", "2026-10-27"]);
        const toMidnight = one({ start: start.toISOString(), end: new Date(2026, 9, 26, 0, 0).toISOString() });
        compare(Object.keys(CalendarEvents.byDay([toMidnight])), ["2026-10-25"]);
    }

    function test_ordersEachDay() {
        const day = (hour, minute) => new Date(2026, 9, 21, hour, minute).toISOString();
        const days = CalendarEvents.byDay(CalendarEvents.events([
            raw({ id: "late", start: day(16, 0), end: day(17, 0) }),
            raw({ id: "allday", allDay: true, start: "2026-10-21T00:00:00Z", end: "2026-10-22T00:00:00Z" }),
            raw({ id: "early", start: day(9, 0), end: day(9, 30) })
        ], calendars));
        compare(days["2026-10-21"].map(item => item.id), ["allday", "early", "late"]);
    }

    function test_findsMeetingLinks() {
        compare(one({ location: "https://meet.google.com/abc-defg-hij" }).meetingUrl, "https://meet.google.com/abc-defg-hij");
        compare(one({ description: "Join (https://acme.zoom.us/j/123?pwd=x) today" }).meetingUrl, "https://acme.zoom.us/j/123?pwd=x");
        compare(one({ description: "Agenda: https://example.com/doc" }).meetingUrl, "");
        compare(one({ meetingUrl: "https://meet.google.com/own", location: "https://zoom.us/j/1" }).meetingUrl, "https://meet.google.com/own");
    }

    function test_marksRepeatsDeclinesAndReadOnly() {
        compare(one({ recurrence: { rrule: ["RRULE:FREQ=WEEKLY"] } }).recurring, true);
        compare(one({ recurringId: "u1" }).recurring, true);
        compare(one({ attendees: [{ email: "me@example.com", status: "DECLINED" }] }).declined, true);
        compare(one({ attendees: [{ email: "mailto:me@example.com", status: "accepted" }] }).declined, false);
        compare(one({ calendarId: "holidays" }).readOnly, true);
        compare(one({ calendarId: "unknown" }).readOnly, true);
    }

    function test_leavesOutWhatIsNotShown() {
        compare(one({ status: "cancelled" }), null);
        compare(one({ calendarId: "muted" }), null);
        compare(one({ start: "soon" }), null);
        compare(one({ meetingUrl: "javascript:alert(1)", url: "http://example.com" }).meetingUrl, "");
        compare(one({ summary: "", visibility: "private" }).title, "Busy");
        compare(one({ summary: "  " }).title, "(No title)");
    }

    function test_times_data() {
        return [
            { tag: "hour", text: "9", minutes: 540 },
            { tag: "colon", text: "09:30", minutes: 570 },
            { tag: "digits", text: "930", minutes: 570 },
            { tag: "h", text: "14h30", minutes: 870 },
            { tag: "pm", text: "2pm", minutes: 840 },
            { tag: "spaced pm", text: "2:30 PM", minutes: 870 },
            { tag: "short pm", text: "2p", minutes: 840 },
            { tag: "midnight", text: "12am", minutes: 0 },
            { tag: "noon", text: "12pm", minutes: 720 },
            { tag: "too late", text: "24:00", minutes: -1 },
            { tag: "bad minutes", text: "9:75", minutes: -1 },
            { tag: "bad 12h", text: "13pm", minutes: -1 },
            { tag: "words", text: "soon", minutes: -1 },
            { tag: "empty", text: "", minutes: -1 }
        ];
    }

    function test_times(data) {
        compare(CalendarEvents.parseTime(data.text), data.minutes);
    }

    function test_draftsBecomeParams() {
        const day = new Date(2026, 9, 21);
        const timed = CalendarEvents.params({ title: " Lunch ", day: day, allDay: false, startText: "13", endText: "", location: "", calendarId: "work" });
        compare(timed.summary, "Lunch");
        compare(Date.parse(timed.start), new Date(2026, 9, 21, 13, 0).getTime());
        compare(Date.parse(timed.end), new Date(2026, 9, 21, 14, 0).getTime());
        const overnight = CalendarEvents.params({ title: "Shift", day: day, allDay: false, startText: "22:00", endText: "6:00", calendarId: "work" });
        compare(Date.parse(overnight.end), new Date(2026, 9, 22, 6, 0).getTime());
        const allDay = CalendarEvents.params({ title: "Off", day: day, allDay: true, startText: "nonsense", calendarId: "work" });
        compare(allDay.allDay, true);
        compare(allDay.start.substring(0, 19), "2026-10-21T00:00:00");
        compare(allDay.end.substring(0, 19), "2026-10-22T00:00:00");
        verify(CalendarEvents.params({ title: "x", day: day, allDay: false, startText: "later" }).error !== undefined);
        verify(CalendarEvents.params({ title: "x", day: day, allDay: false, startText: "9", endText: "eh" }).error !== undefined);
    }

    function test_keepsHowManyDaysAnEventRuns() {
        const trip = one({ start: new Date(2026, 9, 25, 18, 0).toISOString(), end: new Date(2026, 9, 27, 10, 0).toISOString() });
        compare(CalendarEvents.endDays(trip), 2);
        compare(CalendarEvents.endDays(one({ start: new Date(2026, 9, 25, 18, 0).toISOString(), end: new Date(2026, 9, 26, 0, 0).toISOString() })), 0);
        compare(CalendarEvents.endDays(one({ allDay: true, start: "2026-10-23T00:00:00Z", end: "2026-10-26T00:00:00Z" })), 3);
        const moved = CalendarEvents.params({ title: "Trip", day: new Date(2026, 10, 1), allDay: false, startText: "18:00", endText: "10:00", endDays: 2, calendarId: "work" });
        compare(Date.parse(moved.end), new Date(2026, 10, 3, 10, 0).getTime());
        const holidays = CalendarEvents.params({ title: "Off", day: new Date(2026, 10, 1), allDay: true, endDays: 3, calendarId: "work" });
        compare(holidays.end.substring(0, 10), "2026-11-04");
    }

    function test_writesLocalTimesWithTheirOffset() {
        const date = new Date(2026, 0, 5, 7, 4, 3);
        const text = CalendarEvents.rfc3339(date);
        verify(/^2026-01-05T07:04:03[+-]\d\d:\d\d$/.test(text), text);
        compare(Date.parse(text), date.getTime());
    }
}
