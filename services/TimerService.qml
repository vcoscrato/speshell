pragma Singleton

import QtQuick
import Quickshell
import "TimerProvider.js" as TimerProvider

// The timer: counts down a length, pauses and resumes, and notifies when it ends,
// even through Do Not Disturb. The bar shows it while it runs; the Tools panel, the
// launcher's `!timer`, and `speshell timer` set it.
Singleton {
    id: root

    // Set, counting down or paused.
    property bool running: false
    property bool paused: false
    property int totalSeconds: 0
    property int remainingSeconds: 0
    // When it ends, while counting down.
    property double endsAtMs: 0

    // Starts a timer of `seconds`, replacing a running one.
    function start(seconds) {
        const length = Math.round(Number(seconds) || 0);
        if (length <= 0)
            return false;
        root.totalSeconds = length;
        root.remainingSeconds = length;
        root.endsAtMs = Date.now() + length * 1000;
        root.paused = false;
        root.running = true;
        return true;
    }

    // Lengthens a running timer, or starts one.
    function add(seconds) {
        const extra = Math.round(Number(seconds) || 0);
        if (!root.running)
            return root.start(extra);
        if (extra <= 0)
            return false;
        root.totalSeconds += extra;
        root.remainingSeconds += extra;
        if (!root.paused)
            root.endsAtMs += extra * 1000;
        return true;
    }

    function pause() {
        if (!root.running || root.paused)
            return false;
        root.update();
        root.paused = true;
        return true;
    }

    function resume() {
        if (!root.running || !root.paused)
            return false;
        root.endsAtMs = Date.now() + root.remainingSeconds * 1000;
        root.paused = false;
        return true;
    }

    function stop() {
        const wasRunning = root.running;
        root.running = false;
        root.paused = false;
        root.endsAtMs = 0;
        root.totalSeconds = 0;
        root.remainingSeconds = 0;
        return wasRunning;
    }

    function update() {
        if (!root.running || root.paused)
            return;
        root.remainingSeconds = Math.max(0, Math.ceil((root.endsAtMs - Date.now()) / 1000));
        if (root.remainingSeconds > 0)
            return;
        const length = TimerProvider.formatLength(root.totalSeconds);
        root.stop();
        NotificationService.addInternalNotification("timer", "Time's up", "Your " + length + " timer has ended.", true);
    }

    // Ticks just after each whole second left, so the count steps evenly.
    Timer {
        id: ticker
        interval: 1000
        running: root.running && !root.paused
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.update();
            ticker.interval = (root.endsAtMs - Date.now()) % 1000 + 20;
        }
    }
}
