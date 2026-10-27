import QtQuick

// Effect clock shared by every effect. Emits `advanced(dt)` about `frameRate` times a
// second with the elapsed time, and steps `simTime` in fixed 1 / `frameRate` s
// increments, so the timer's jitter does not show. A `frameRate` of 0 ticks with every
// frame the display shows, whose times are already even, so `simTime` follows `clock`.
//
// Time runs at Speshell's transition speed and frame rate: an ancestor item with a
// `timeScale` property (Speshell's transition host) scales every step, and its
// `frameRate`, if it has one, sets the tick rate. Otherwise the clock ticks at 60 Hz.
//
// Inside the offscreen previews, an ancestor item with a `previewTime` property drives the
// clock instead of the wall clock, so previews are frame-exact however slowly
// frames are captured.
Item {
    id: root

    readonly property real step: 1 / Math.max(1, root.frameRate)
    property real clock: 0
    property real simTime: 0
    property real acc: 0
    property real lastTime: -1

    // Emitted last in each tick, so a handler may cause this clock to be destroyed.
    signal advanced(real dt)

    readonly property Item speedHost: {
        for (var item = root.parent; item; item = item.parent) {
            if (item.timeScale !== undefined)
                return item;
        }
        return null;
    }
    readonly property real timeScale: root.speedHost ? Math.max(0, root.speedHost.timeScale) : 1
    readonly property int frameRate: root.speedHost && root.speedHost.frameRate !== undefined
        ? Math.max(0, root.speedHost.frameRate) : 60
    readonly property bool everyFrame: root.frameRate === 0

    readonly property Item previewHost: {
        for (var item = root.parent; item; item = item.parent) {
            if (item.previewTime !== undefined)
                return item;
        }
        return null;
    }

    function tick(now) {
        var dt = (root.lastTime < 0 ? root.step : Math.min(0.1, now - root.lastTime)) * root.timeScale;
        root.lastTime = now;
        root.advance(dt);
    }

    function advance(dt) {
        if (dt <= 0)
            return;
        root.clock += dt;
        if (root.everyFrame) {
            root.simTime += dt;
            root.advanced(dt);
            return;
        }
        root.acc += dt;
        // Fast speeds take several steps per tick; a stall over 8 frames at 60 Hz
        // drops the backlog.
        if (root.acc > 8 / 60)
            root.acc = root.step;
        // Rounded to whole steps, so a tick a little early still takes its step.
        while (root.acc >= root.step / 2) {
            root.acc -= root.step;
            root.simTime += root.step;
        }
        root.advanced(dt);
    }

    // Timers fire on whole milliseconds, so each tick aims at the next multiple of the
    // frame period: intervals alternate (7, 7, 6, ... ms at 144 Hz) and average out.
    property real nextDue: 0

    Timer {
        id: ticker
        interval: Math.max(1, Math.round(1000 * root.step))
        repeat: true
        running: root.previewHost === null && !root.everyFrame
        onTriggered: {
            var now = Date.now();
            var period = 1000 * root.step;
            // Started, or more than a frame off schedule: restart the schedule now.
            if (Math.abs(now - root.nextDue) > period)
                root.nextDue = now;
            root.nextDue += period;
            // Before the tick: its handlers may destroy this clock.
            ticker.interval = Math.max(1, Math.round(root.nextDue - now));
            root.tick(now / 1000);
        }
    }

    FrameAnimation {
        running: root.previewHost === null && root.everyFrame
        // Capped as the timer's ticks are, so a stall does not leap ahead.
        onTriggered: root.advance(Math.min(0.1, frameTime) * root.timeScale)
    }

    Connections {
        target: root.previewHost
        function onPreviewTimeChanged() { root.tick(root.previewHost.previewTime); }
    }
}
