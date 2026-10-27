import QtQuick
import "common"
import "Sugar.js" as Sugar

// Sugar launcher transition: the launcher opens at once, and while you use it a
// piping bag comes in at its top-left corner and slowly pipes a shell border of
// frosting round it, just outside its edge; done, it lifts away, and sugar pearls are
// set into the border one by one, now and then catching the light. Closing, it is
// eaten: bites chomp in from its edges, showing the sponge inside and throwing
// crumbs, until a last big bite takes the rest.
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
    readonly property real pipeStart: 0.15
    readonly property real pipeTime: 3.2
    readonly property real liftTime: 0.5
    readonly property real pearlTime: 1.4
    readonly property real exitTime: 0.48
    readonly property real tailTime: 0.25       // the last crumbs falling

    // open: seconds open, which paces the decorating; leave: 0..1 over the bites.
    property real open: 0
    property real leave: 0
    property real tailStart: 0
    property bool exitDone: false
    // Bites already taken, so each throws its crumbs once.
    property int bitten: 0
    // Where the bites land: (x, y) on the panel, relative to its top-left, as a
    // fraction of its size; z the bite's size as a fraction of the panel's shorter side.
    property var bites: []
    property real nextGlint: 0.6

    readonly property real pipeEnd: pipeStart + pipeTime
    readonly property real pipe: span(open, pipeStart, pipeEnd)
    readonly property real pearls: span(open, pipeEnd + 0.2, pipeEnd + 0.2 + pearlTime)
    readonly property real radius: root.theme && root.theme.surfaceRadius !== undefined ? root.theme.surfaceRadius : 16
    readonly property bool capturing: leave > 0
    readonly property real margin: 140
    // When each bite starts, as leave; the last is the big one.
    readonly property var biteAt: [0.0, 0.18, 0.36, 0.6]

    function span(x, a, b) { return Math.max(0, Math.min(1, (x - a) / (b - a))); }

    // Where the bites land: three on different sides, and the last on the fourth.
    function planBites() {
        var plan = [];
        var sides = [0, 1, 2, 3].sort(function() { return Math.random() - 0.5; });
        for (var i = 0; i < 3; i++) {
            var t = 0.15 + 0.7 * Math.random();
            var side = sides[i];
            var x = side === 0 ? t : side === 1 ? 1.02 : side === 2 ? t : -0.02;
            var y = side === 0 ? -0.02 : side === 1 ? t : side === 2 ? 1.02 : t;
            plan.push(Qt.vector3d(x, y, 0.32 + 0.12 * Math.random()));
        }
        // The last, from the side not yet bitten, takes the rest.
        var t3 = 0.3 + 0.4 * Math.random(), s3 = sides[3];
        plan.push(Qt.vector3d(s3 === 0 || s3 === 2 ? t3 : s3 === 1 ? 1.05 : -0.05,
                              s3 === 1 || s3 === 3 ? t3 : s3 === 0 ? -0.05 : 1.05, 0));
        root.bites = plan;
    }

    function biteUniform(i) {
        var r = root.panelRect;
        if (root.bites.length <= i)
            return Qt.vector4d(0, 0, 0, 0);
        var b = root.bites[i];
        var k = root.span(root.leave, root.biteAt[i], root.biteAt[i] + (i === 3 ? 0.36 : 0.16));
        // The jaws snap shut a little past the bite, then settle on it.
        var snap = k <= 0 ? 0 : 1 + 2.2 * Math.pow(k - 1, 3) + 1.2 * Math.pow(k - 1, 2);
        // The last reaches the corner furthest from it.
        var size = i === 3 ? Math.hypot(Math.max(b.x, 1 - b.x) * r.width, Math.max(b.y, 1 - b.y) * r.height) + 30
                           : Math.min(r.width, r.height) * b.z;
        return Qt.vector4d(r.x + b.x * r.width, r.y + b.y * r.height, size * snap, i * 1.7 + 0.3);
    }

    onActiveChanged: exitDone = false

    EffectClock {
        id: clock
        onAdvanced: function(dt) {
            if (root.active) {
                // Reopened mid-exit: it grows back.
                if (root.leave > 0)
                    root.leave = Math.max(0, root.leave - dt / root.exitTime);
                else
                    root.open += dt;
            } else if (root.leave < 1) {
                if (root.leave === 0)
                    root.planBites();
                root.leave = Math.min(1, root.leave + dt / root.exitTime);
                root.tailStart = clock.clock;
            } else if (!root.exitDone && clock.clock - root.tailStart >= root.tailTime) {
                root.exitDone = true;
                // Speshell may destroy this item inside the signal, so nothing may follow it.
                root.closingFinished();
                return;
            }

            if (!root.active && root.leave > 0) {
                while (root.bitten < root.biteAt.length && root.leave >= root.biteAt[root.bitten]) {
                    root.crumbs(root.bitten);
                    root.bitten++;
                }
            } else {
                root.bitten = 0;
            }
            // Once the pearls are set, now and then one catches the light.
            if (root.active && root.leave === 0 && root.pearls >= 1) {
                root.nextGlint -= dt;
                if (root.nextGlint <= 0) {
                    root.nextGlint = bits.rnd(1.2, 2.6);
                    root.glint();
                }
            }
        }
    }

    // A glint on a pearl somewhere along the border.
    function glint() {
        var r = root.panelRect, side = Math.random(), x, y;
        if (side < 0.35) {
            x = r.x + r.width * bits.rnd(0.05, 0.95); y = r.y - 4;
        } else if (side < 0.55) {
            x = r.x - 4; y = r.y + r.height * bits.rnd(0.1, 0.9);
        } else if (side < 0.75) {
            x = r.x + r.width + 4; y = r.y + r.height * bits.rnd(0.1, 0.9);
        } else {
            x = r.x + r.width * bits.rnd(0.05, 0.95); y = r.y + r.height + 4;
        }
        bits.emit(bits.sparkle, { x: x, y: y, life: 0.45, size: Math.round(bits.rnd(9, 13)) });
    }

    // Crumbs thrown from bite i as it closes.
    function crumbs(i) {
        var b = root.biteUniform(i);
        var c = root.bites[i];
        var r = root.panelRect;
        var n = i === 3 ? 10 : 6;
        for (var k = 0; k < n; k++) {
            // From round the bite's edge, flung outward and falling.
            var a = Math.random() * 2 * Math.PI;
            var reach = Math.min(r.width, r.height) * (i === 3 ? bits.rnd(0.2, 0.6) : c.z * bits.rnd(0.6, 1.0));
            var x = r.x + c.x * r.width + Math.cos(a) * reach;
            var y = r.y + c.y * r.height + Math.sin(a) * reach;
            bits.emit(bits.crumb, { x: x, y: y, vx: Math.cos(a) * bits.rnd(60, 220), vy: Math.sin(a) * bits.rnd(60, 160) - 120,
                                    gravity: 900, angle: bits.rnd(0, 360), spin: bits.rnd(-300, 300),
                                    life: bits.rnd(0.5, 0.75), size: Math.round(bits.rnd(14, 26)), delay: i === 3 ? 0.1 : 0.04 });
        }
        if (i < 3)
            bits.emit(bits.puff, { x: b.x, y: b.y, vy: -20, drag: 2, life: 0.45, size: 44, delay: 0.04 });
    }

    ShaderEffectSource {
        id: panelTex
        sourceItem: root.panel
        hideSource: root.capturing
        live: root.capturing
    }

    ShaderEffect {
        x: root.panelRect.x - root.margin
        y: root.panelRect.y - root.margin
        width: root.panelRect.width + 2 * root.margin
        height: root.panelRect.height + 2 * root.margin
        visible: root.panel !== null && (root.leave < 1 || root.active)
        property var source: panelTex
        property point origin: Qt.point(x, y)
        property size resolution: Qt.size(width, height)
        property rect rect: root.panelRect
        property real radius: root.radius
        property real capture: root.capturing ? 1 : 0
        property real pipe: root.pipe
        // The bag coming in, and lifting away when done.
        property real arrive: root.span(root.open, 0, root.pipeStart + 0.15)
        property real lift: root.span(root.open, root.pipeEnd, root.pipeEnd + root.liftTime)
        property real pearls: root.pearls
        property vector4d bite0: { root.leave; return root.biteUniform(0); }
        property vector4d bite1: { root.leave; return root.biteUniform(1); }
        property vector4d bite2: { root.leave; return root.biteUniform(2); }
        property vector4d bite3: { root.leave; return root.biteUniform(3); }
        property color cFrost: Sugar.frosting(root.theme)
        property color cFrostLight: Sugar.frostingLight(root.theme)
        property color cFrostShade: Sugar.frostingShade(root.theme)
        property color cFilm: Sugar.sparkle(root.theme)
        property color cMetal: Sugar.metal(root.theme)
        property color cMetalShade: Sugar.metalShade(root.theme)
        property color cSponge: Sugar.sponge(root.theme)
        property color cCream: Sugar.cream(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.qsb")
    }

    Bits {
        id: bits
        anchors.fill: parent
        theme: root.theme
    }
}
