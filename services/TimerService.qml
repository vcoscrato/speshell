pragma Singleton

import QtQuick
import Quickshell
import "TimerProvider.js" as TimerProvider

// The timers: each counts down a length, pauses and resumes, and notifies when it ends,
// even through Do Not Disturb, then goes. Tools creates one unset, and the bar holds
// each, where it is set and controlled; `speshell timer` starts and controls them too.
Singleton {
    id: root

    // Every timer, in the order they were created.
    property var timers: []
    property int lastKey: 0

    // Any timer started, ended, or changed, beyond its count.
    signal changed()

    component Countdown: QtObject {
        property int key: 0
        property string name: ""
        // 0 until it is set.
        property int totalSeconds: 0
        property int remainingSeconds: 0
        // When it ends, while counting down.
        property double endsAtMs: 0
        property bool paused: false
        readonly property bool isSet: totalSeconds > 0
    }

    Component {
        id: countdownComponent
        Countdown {}
    }

    // A new unset timer, or the one that already waits to be set.
    function create() {
        for (const timer of root.timers) {
            if (!timer.isSet)
                return timer;
        }
        root.lastKey++;
        const timer = countdownComponent.createObject(root, { key: root.lastKey }) as Countdown;
        root.timers = root.timers.concat([timer]);
        root.changed();
        return timer;
    }

    // Starts a new timer of `seconds`, named `name`, or returns null when it isn't a length.
    function start(seconds, name) {
        if (Math.round(Number(seconds) || 0) <= 0)
            return null;
        root.lastKey++;
        const timer = countdownComponent.createObject(root, { key: root.lastKey, name: String(name || "").trim() }) as Countdown;
        root.timers = root.timers.concat([timer]);
        root.set(timer, seconds);
        return timer;
    }

    // Sets `timer` counting down `seconds` from now.
    function set(timer, seconds) {
        const length = Math.round(Number(seconds) || 0);
        if (!timer || length <= 0)
            return false;
        timer.totalSeconds = length;
        timer.remainingSeconds = length;
        timer.endsAtMs = Date.now() + length * 1000;
        timer.paused = false;
        root.changed();
        return true;
    }

    // Lengthens `timer`, or shortens it by less than it has left.
    function add(timer, seconds) {
        const change = Math.round(Number(seconds) || 0);
        if (!timer || !timer.isSet || change === 0 || timer.remainingSeconds + change <= 0)
            return false;
        timer.totalSeconds = Math.max(timer.remainingSeconds + change, timer.totalSeconds + change);
        timer.remainingSeconds += change;
        if (!timer.paused)
            timer.endsAtMs += change * 1000;
        root.changed();
        return true;
    }

    function pause(timer) {
        if (!timer || !timer.isSet || timer.paused)
            return false;
        root.update(timer);
        timer.paused = true;
        root.changed();
        return true;
    }

    function resume(timer) {
        if (!timer || !timer.paused)
            return false;
        timer.endsAtMs = Date.now() + timer.remainingSeconds * 1000;
        timer.paused = false;
        root.changed();
        return true;
    }

    function toggle(timer) {
        return timer && timer.paused ? root.resume(timer) : root.pause(timer);
    }

    function rename(timer, name) {
        if (!timer)
            return false;
        timer.name = String(name || "").trim();
        root.changed();
        return true;
    }

    // Takes `timer` away.
    function stop(timer) {
        if (root.timers.indexOf(timer) < 0)
            return false;
        root.timers = root.timers.filter(other => other !== timer);
        timer.destroy();
        root.changed();
        return true;
    }

    // The set timer named `name`, ignoring case; with no name, the one that ends first.
    function find(name) {
        const wanted = String(name || "").trim().toLowerCase();
        const candidates = root.timers.filter(timer => timer.isSet
            && (wanted === "" || timer.name.toLowerCase() === wanted));
        return candidates.reduce((first, timer) => first === null
            || timer.remainingSeconds < first.remainingSeconds ? timer : first, null);
    }

    function update(timer) {
        if (!timer.isSet || timer.paused)
            return;
        timer.remainingSeconds = Math.max(0, Math.ceil((timer.endsAtMs - Date.now()) / 1000));
        if (timer.remainingSeconds > 0)
            return;
        NotificationService.addInternalNotification("timer-" + timer.key, timer.name !== "" ? timer.name : "Time's up",
            "Your " + TimerProvider.formatLength(timer.totalSeconds) + " timer has ended.", true);
        root.stop(timer);
    }

    // Ticks just after each whole second left on any timer, so the counts step evenly.
    Timer {
        id: ticker

        readonly property bool counting: root.timers.some(timer => timer.isSet && !timer.paused)

        interval: 1000
        running: ticker.counting
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            const now = Date.now();
            let next = 1000;
            for (const timer of root.timers.slice()) {
                root.update(timer);
                if (timer.isSet && !timer.paused)
                    next = Math.min(next, (timer.endsAtMs - now) % 1000);
            }
            ticker.interval = Math.max(0, next) + 20;
        }
    }
}
