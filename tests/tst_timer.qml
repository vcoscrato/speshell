import QtQuick
import QtTest
import "../services/TimerProvider.js" as TimerProvider

TestCase {
    name: "Timer"

    function test_lengths_data() {
        return [
            { tag: "bare minutes", text: "25", seconds: 1500 },
            { tag: "minutes", text: "25m", seconds: 1500 },
            { tag: "words", text: "2 min", seconds: 120 },
            { tag: "hours and minutes", text: "1h30", seconds: 5400 },
            { tag: "spaced", text: "1h 30m", seconds: 5400 },
            { tag: "seconds", text: "90s", seconds: 90 },
            { tag: "minutes and seconds", text: "1m30", seconds: 90 },
            { tag: "fraction", text: "1.5h", seconds: 5400 },
            { tag: "comma", text: "2,5", seconds: 150 },
            { tag: "upper case", text: " 10M ", seconds: 600 },
            { tag: "a day", text: "24h", seconds: 86400 },
            { tag: "over a day", text: "25h", seconds: 0 },
            { tag: "zero", text: "0", seconds: 0 },
            { tag: "out of order", text: "30m 1h", seconds: 0 },
            { tag: "repeated unit", text: "5m 5m", seconds: 0 },
            { tag: "past seconds", text: "10s 5", seconds: 0 },
            { tag: "words only", text: "soon", seconds: 0 },
            { tag: "empty", text: "", seconds: 0 }
        ];
    }

    function test_lengths(data) {
        compare(TimerProvider.parseDuration(data.text), data.seconds);
    }

    function test_formats() {
        compare(TimerProvider.formatLength(5400), "1 h 30 min");
        compare(TimerProvider.formatLength(1500), "25 min");
        compare(TimerProvider.formatLength(45), "45 s");
        compare(TimerProvider.formatClock(245), "4:05");
        compare(TimerProvider.formatClock(3723), "1:02:03");
    }

    function test_bang() {
        compare(TimerProvider.parseBang("!timer"), "");
        compare(TimerProvider.parseBang("!timer 1h30"), "1h30");
        compare(TimerProvider.parseBang("!TIMER 5"), "5");
        compare(TimerProvider.parseBang("!timers"), null);
        compare(TimerProvider.parseBang("timer 5"), null);
    }

    function test_idleOffersPresetsAndStartsTypedLengths() {
        const idle = { running: false };
        const presets = TimerProvider.timerResults("", idle);
        compare(presets.length, TimerProvider.presets.length);
        compare(presets[0].payload.action, "start");

        const typed = TimerProvider.timerResults("1h30", idle);
        compare(typed.length, 1);
        compare(typed[0].payload.action, "start");
        compare(typed[0].payload.seconds, 5400);

        const invalid = TimerProvider.timerResults("soon", idle);
        compare(invalid[0].activatable, false);
    }

    function test_runningTimerIsControlled() {
        const running = { running: true, paused: false, remaining: 600, endsAt: Date.now() + 600000 };
        compare(TimerProvider.timerResults("", running).map(result => result.payload.action), ["pause", "add", "stop"]);
        const paused = Object.assign({}, running, { paused: true });
        compare(TimerProvider.timerResults("", paused)[0].payload.action, "resume");
        // A typed length extends it first, or replaces it.
        compare(TimerProvider.timerResults("10", running).map(result => result.payload.action), ["add", "start"]);
    }
}
