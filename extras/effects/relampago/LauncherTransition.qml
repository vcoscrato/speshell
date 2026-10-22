import QtQuick
import "common"
import "Bolt.js" as Bolt

// Relâmpago launcher transition, drawn like a cartoon: the launcher races in from
// the left, stretched by its speed, in a streak of glossy red with a bolt decal
// through it, brakes hard, leaving skid marks and a shower of sparks, and squashes
// to a stop with a comic starburst, in puffs of tire smoke, as lightning strikes all
// around it. While open, speed dashes trail off behind it, electricity crackles
// along its border, and now and then a bolt strikes it.
// Closing, it squats, stretches, and tears away to the right on two trails of fire.
Item {
    id: root

    // ── Speshell effects API v1 ────────────────────────────────
    property Item panel: null
    property rect panelRect
    property bool active: false
    // The active palette, as Theme.qml names it.
    property var theme: null
    signal closingFinished()

    // ── Choreography (seconds) ──────────────────────────────
    readonly property real arriveTime: 0.5     // racing in to the stop
    readonly property real settleTime: 0.3     // rocking back on its springs
    readonly property real exitTime: 0.42
    readonly property real tailTime: 0.18      // the fire burning out

    // enter: 0..1 over the arrival and the settle; leave: 0..1 exit progress.
    property real enter: 0
    property real leave: 0
    property real tailStart: 0
    property bool exitDone: false

    // The drive, sampled each tick.
    property real driveX: -root.farLeft
    property real speed: 0
    property real lean: 0
    // Squash and stretch: > 0 stretched along x, < 0 squashed; a spring toward
    // how fast it goes, kicked as it stops and launches.
    property real stretch: 0
    property real stretchVel: 0
    property real travel: 0
    property real skidAge: -1                  // s since it stopped; < 0 before
    property real fireAge: -1                  // s since it tore away; < 0 before
    property real sparkOwed: 0
    property bool primed: false
    property real nextStrike: 1.2              // s until lightning strikes the open panel

    readonly property real arriveEnd: arriveTime / (arriveTime + settleTime)
    readonly property real farLeft: panelRect.x + panelRect.width + 140
    readonly property real farRight: width - panelRect.x + 140
    readonly property bool capturing: enter < 1 || leave > 0
    readonly property real floorY: panelRect.y + panelRect.height
    // The rear tires, about a fifth of the way along the panel.
    readonly property real rear: panelRect.x + driveX + panelRect.width * 0.2

    function span(x, a, b) { return Math.max(0, Math.min(1, (x - a) / (b - a))); }

    // Where the drive puts the panel, from rest, for the current progress.
    function position() {
        if (root.leave > 0)
            return root.farRight * Math.pow(root.leave, 2.4);
        if (root.enter < root.arriveEnd)
            return -root.farLeft * Math.pow(1 - root.enter / root.arriveEnd, 3.2);
        // Past its mark a little as it skids, then back.
        var s = (root.enter - root.arriveEnd) / (1 - root.arriveEnd);
        return 16 * Math.sin(Math.PI * Math.min(1, s * 1.15)) * (1 - s);
    }

    onActiveChanged: exitDone = false

    EffectClock {
        id: clock
        onAdvanced: function(dt) {
            var wasStopped = root.enter >= root.arriveEnd * 0.94;
            var wasLeaving = root.leave > 0;
            if (root.active) {
                // Reopened mid-exit: it backs into place first.
                if (root.leave > 0)
                    root.leave = Math.max(0, root.leave - dt / root.exitTime);
                else
                    root.enter = Math.min(1, root.enter + dt / (root.arriveTime + root.settleTime));
            } else if (root.leave < 1) {
                root.leave = Math.min(1, root.leave + dt / root.exitTime);
                root.tailStart = clock.clock;
            } else if (!root.exitDone && clock.clock - root.tailStart >= root.tailTime) {
                root.exitDone = true;
                // Speshell may destroy this item inside the signal, so nothing may follow it.
                root.closingFinished();
                return;
            }

            var x = root.position();
            if (!root.primed) {
                root.primed = true;
                root.driveX = x;
            }
            var v = (x - root.driveX) / dt;
            var accel = (v - root.speed) / dt;
            root.driveX = x;
            root.speed = v;
            // Leans into braking and back from acceleration, settling by the end.
            var want = Math.max(-14, Math.min(14, -accel * 0.0009)) * (1 - root.span(root.enter, 0.85, 1) * (root.leave > 0 ? 0 : 1));
            root.lean += (want - root.lean) * Math.min(1, dt * 18);
            if (root.enter >= 1 && root.leave === 0)
                root.lean = 0;
            var stretchTo = Math.min(0.2, Math.abs(v) / 9000);
            root.stretchVel += (380 * (stretchTo - root.stretch) - 13 * root.stretchVel) * dt;
            root.stretch = Math.max(-0.2, Math.min(0.25, root.stretch + root.stretchVel * dt));
            root.travel += dt * (650 + Math.abs(v) * 0.5);

            if (root.skidAge >= 0)
                root.skidAge += dt;
            if (root.fireAge >= 0)
                root.fireAge += dt;
            // Sparks off the rear while braking hard.
            if (root.leave === 0 && root.enter < root.arriveEnd && x > -320) {
                root.sparkOwed += Math.abs(v) * dt;
                while (root.sparkOwed > 26) {
                    root.sparkOwed -= 26;
                    bits.emit(bits.spark, { x: root.rear, y: root.floorY + bits.rnd(4, 14), vx: bits.rnd(-260, -60),
                                            vy: bits.rnd(-200, -40), gravity: 700, life: bits.rnd(0.3, 0.5),
                                            size: Math.round(bits.rnd(16, 24)), orient: true });
                }
            }
            // Now and then while open, lightning strikes it.
            if (root.active && root.enter >= 1 && root.leave === 0) {
                root.nextStrike -= dt;
                if (root.nextStrike <= 0) {
                    root.nextStrike = bits.rnd(0.9, 2.2);
                    root.strikeBorder(0);
                }
            }
            if (!wasStopped && root.enter >= root.arriveEnd * 0.94 && root.leave === 0)
                root.stopped();
            if (!wasLeaving && root.leave > 0 && !root.active)
                root.launched();
        }
    }

    // Skidded to its mark: smoke from the tires, sparks off the front, and lightning.
    function stopped() {
        root.skidAge = 0;
        root.stretchVel -= 4.5;
        var x0 = root.panelRect.x, w = root.panelRect.width;
        for (var i = 0; i < 6; i++)
            bits.emit(bits.smoke, { x: x0 + w * bits.rnd(0.05, 0.3), y: root.floorY + bits.rnd(0, 12),
                                    vx: bits.rnd(-90, -20), vy: bits.rnd(-50, -10), drag: 1.5,
                                    life: bits.rnd(0.9, 1.3), size: Math.round(bits.rnd(64, 104)), delay: i * 0.03 });
        for (i = 0; i < 4; i++)
            bits.emit(bits.smoke, { x: x0 + w * bits.rnd(0.72, 0.92), y: root.floorY + bits.rnd(0, 10),
                                    vx: bits.rnd(-30, 50), vy: bits.rnd(-40, -10), drag: 1.5,
                                    life: bits.rnd(0.7, 1.0), size: Math.round(bits.rnd(48, 76)), delay: 0.04 + i * 0.03 });
        for (i = 0; i < 10; i++)
            bits.emit(bits.spark, { x: x0 + w * bits.rnd(0.78, 0.95), y: root.floorY + 6, vx: bits.rnd(60, 320),
                                    vy: bits.rnd(-260, -60), gravity: 800, life: bits.rnd(0.35, 0.6),
                                    size: Math.round(bits.rnd(18, 28)), orient: true });
        // A comic impact off its front, behind it, and a glint on its paint.
        behind.emit(behind.star, { x: x0 + w + 6, y: root.floorY - root.panelRect.height * 0.35, life: 0.32,
                                   size: Math.round(Math.min(200, root.panelRect.height * 0.55)), angle: bits.rnd(0, 360) });
        bits.emit(bits.glint, { x: x0 + 18, y: root.panelRect.y + 6, life: 0.45, size: 30, delay: 0.12 });
        // Lightning strikes it from all around as it stops.
        for (i = 0; i < 4; i++)
            root.strikeBorder(0.03 + i * bits.rnd(0.05, 0.09));
    }

    // A bolt striking a random point of the panel's border from outside, mostly from
    // above, after `delay` s.
    function strikeBorder(delay) {
        var r = root.panelRect, side = Math.random(), x, y, angle;
        if (side < 0.5) {
            x = r.x + r.width * bits.rnd(0.1, 0.9); y = r.y; angle = 0;
        } else if (side < 0.7) {
            x = r.x; y = r.y + r.height * bits.rnd(0.15, 0.85); angle = -90;
        } else if (side < 0.9) {
            x = r.x + r.width; y = r.y + r.height * bits.rnd(0.15, 0.85); angle = 90;
        } else {
            x = r.x + r.width * bits.rnd(0.1, 0.9); y = r.y + r.height; angle = 180;
        }
        bits.emit(bits.strike, { x: x, y: y, life: bits.rnd(0.4, 0.55), size: Math.round(bits.rnd(260, 440)),
                                 angle: angle + bits.rnd(-25, 25), delay: delay });
        for (var i = 0; i < 3; i++)
            bits.emit(bits.spark, { x: x, y: y, vx: bits.rnd(-200, 200), vy: bits.rnd(-220, 40), gravity: 700,
                                    life: bits.rnd(0.25, 0.45), size: Math.round(bits.rnd(16, 24)), orient: true,
                                    delay: delay + 0.04 });
    }

    // Tore away: a burnout, smoke and sparks flung back off the rear.
    function launched() {
        root.fireAge = 0;
        root.stretchVel -= 3;
        root.skidAge = Math.max(root.skidAge, 0.8);
        for (var i = 0; i < 6; i++)
            bits.emit(bits.smoke, { x: root.rear + bits.rnd(-30, 10), y: root.floorY + bits.rnd(0, 12),
                                    vx: bits.rnd(-140, -40), vy: bits.rnd(-60, -10), drag: 1.8,
                                    life: bits.rnd(0.5, 0.7), size: Math.round(bits.rnd(56, 90)), delay: i * 0.02 });
        for (i = 0; i < 8; i++)
            bits.emit(bits.spark, { x: root.rear, y: root.floorY + 8, vx: bits.rnd(-340, -100), vy: bits.rnd(-220, -40),
                                    gravity: 800, life: bits.rnd(0.3, 0.5), size: Math.round(bits.rnd(18, 26)), orient: true });
    }

    // ── Around the panel: speed lines, crackle, skid marks, and fire ──
    ShaderEffect {
        anchors.fill: parent
        visible: lines > 0 || skid > 0 || fire > 0
        property size resolution: Qt.size(width, height)
        property real time: clock.simTime
        property rect rect: Qt.rect(root.panelRect.x + root.driveX, root.panelRect.y, root.panelRect.width, root.panelRect.height)
        property real radius: 12
        property real lines: root.span(root.enter, 0, 0.12) * (1 - root.span(root.leave, 0.5, 1))
        // Once it stands, the dashes draw back behind it.
        property real calm: root.leave > 0 ? 1 - root.span(root.leave, 0, 0.3) : root.span(root.enter, root.arriveEnd, 1)
        property real spread: 1 + Math.min(2.5, Math.abs(root.speed) / 900)
        property real travel: root.travel % 1e6
        property real arcs: root.span(root.enter, root.arriveEnd, 1) * (1 - root.span(root.leave, 0, 0.15))
        property real skid: root.skidAge < 0 ? (root.driveX > -300 && root.leave === 0 ? 1 : 0)
                                             : Math.max(0, 1 - root.skidAge / 1.4)
        property point skidSpan: Qt.point(root.panelRect.x - 260, root.rear)
        property real fire: root.fireAge < 0 ? 0 : Math.max(0, Math.min(1, 1 - (root.fireAge - 0.18) / 0.42))
        property point fireSpan: Qt.point(root.panelRect.x + root.panelRect.width * 0.2, root.rear)
        property real trackY: root.floorY
        property color cLine: root.theme ? root.theme.text : "#f6eee8"
        property color cCore: Bolt.core(root.theme)
        property color cGlow: Bolt.glow(root.theme)
        property color cEdge: Bolt.edge(root.theme)
        property color cPaint: Bolt.paint(root.theme)
        property color cRubber: Bolt.rubber(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.track.qsb")
    }

    // Under the racing panel: the starburst it stops in. Shown only while the panel
    // is drawn here, since the real one lies under this whole item.
    Bits {
        id: behind
        anchors.fill: parent
        visible: root.capturing
        theme: root.theme
    }

    // ── The panel, racing; otherwise the real panel shows ──
    ShaderEffectSource {
        id: panelTex
        sourceItem: root.panel
        hideSource: root.capturing
        live: root.capturing
    }

    ShaderEffect {
        visible: root.capturing && root.panel !== null
        x: 0
        y: root.panelRect.y - 24 - root.panelRect.height * 0.25
        width: root.width
        height: root.panelRect.height * 1.25 + 48
        property var source: panelTex
        property point origin: Qt.point(x, y)
        property size resolution: Qt.size(width, height)
        property rect rect: root.panelRect
        property real offset: root.driveX
        property real smear: Math.min(Math.abs(root.speed) * 0.05, 420)
        property real dir: root.speed >= 0 ? 1 : -1
        property real lean: root.lean
        // Settled by the time the real panel shows again.
        property real stretch: root.stretch * (root.leave > 0 ? 1 : 1 - root.span(root.enter, 0.85, 1))
        property real heat: Math.min(1, Math.abs(root.speed) / 1600)
        property color cPaint: Bolt.paint(root.theme)
        property color cGlow: Bolt.glow(root.theme)
        property color cEdge: Bolt.edge(root.theme)
        property color cCore: Bolt.core(root.theme)
        property color cRubber: Bolt.rubber(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.qsb")
    }

    Bits {
        id: bits
        anchors.fill: parent
        theme: root.theme
    }
}
