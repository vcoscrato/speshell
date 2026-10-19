import QtQuick
import QtTest
import "../services/TimerProvider.js" as TimerProvider
import "../components/Format.js" as Format

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
        compare(Format.duration(5400), "1 h 30 min");
        compare(Format.duration(1500), "25 min");
        compare(Format.duration(45), "45 s");
        compare(Format.clock(245), "4:05");
        compare(Format.clock(3723), "1:02:03");
    }

    // 18 Oct 2026, 21:00.
    readonly property double now: new Date(2026, 9, 18, 21, 0).getTime()

    function test_lengthsAndNames_data() {
        return [
            { tag: "length", text: "25", seconds: 1500, name: "" },
            { tag: "name after", text: "10 pasta", seconds: 600, name: "pasta" },
            { tag: "name before", text: "tea 4m", seconds: 240, name: "tea" },
            { tag: "spaced length", text: "1h 30 bread rise", seconds: 5400, name: "bread rise" },
            { tag: "end time", text: "bread at 21:30", seconds: 1800, name: "bread" },
            { tag: "end hour tomorrow", text: "at 7", seconds: 36000, name: "" },
            { tag: "until", text: "until 20:00 call", seconds: 82800, name: "call" },
            { tag: "not a time", text: "at 25:00", seconds: 0, name: "at 25:00" },
            { tag: "name only", text: "pasta", seconds: 0, name: "pasta" },
            { tag: "empty", text: "", seconds: 0, name: "" }
        ];
    }

    function test_lengthsAndNames(data) {
        const parsed = TimerProvider.parseTimer(data.text, now);
        compare(parsed.seconds, data.seconds);
        compare(parsed.name, data.name);
    }
}
