import QtQuick
import "Flame.js" as Flame
import "common"

// Fire wallpaper transition: the old wallpaper catches near the middle of the screen,
// where the launcher was, and burns away outward to the new one, embers drifting up
// off the burnt ground behind the front.
Item {
    id: root

    // ── Speshell effects API v1 ────────────────────────────────
    property Item outgoing: null
    // The active palette, as Theme.qml names it.
    property var theme: null
    signal finished()

    // ── Choreography (seconds) ──────────────────────────────
    readonly property real spreadTime: 1.6
    readonly property real tailTime: 0.45      // flames left burning after the front passes
    readonly property real fieldScale: 4

    readonly property color core: Flame.core(root.theme)

    property real sweep: 0
    property real tailStart: 0
    property bool done: false
    // Embers owed to the burnt ground, paid out as the front passes over it.
    property real embersOwed: 0

    function rnd(a, b) {
        return a + Math.random() * (b - a);
    }

    // Embers rise off ground the front has just passed, more as the front grows, and
    // burn out before the transition ends.
    function shedEmbers(dt) {
        var left = root.spreadTime + root.tailTime - clock.clock - 0.05;
        if (root.burnR < 60 || left < 0.3)
            return;
        root.embersOwed += dt * Math.min(90, root.burnR / 7);
        while (root.embersOwed >= 1) {
            root.embersOwed -= 1;
            var a = Math.random() * 2 * Math.PI;
            var r = root.burnR - root.rnd(70, 260);
            var x = root.origin.x + Math.cos(a) * r, y = root.origin.y + Math.sin(a) * r;
            if (r < 0 || x < 0 || x > root.width || y < 0 || y > root.height)
                continue;
            embers.spawn({ x: x, y: y, vx: root.rnd(-30, 30), vy: -root.rnd(60, 140), gravity: -root.rnd(30, 80),
                           drag: 0.8, life: Math.min(left, root.rnd(0.8, 1.4)), size: Math.round(root.rnd(30, 46)),
                           props: { kind: 4, seed: Math.random(), z: 2 } });
        }
    }
    readonly property point origin: Qt.point(width * 0.5, height * 0.55)
    // Past this radius the ragged front has cleared every screen corner.
    readonly property real maxRadius: Math.sqrt(Math.pow(width * 0.5 * 0.85, 2) + Math.pow(height * 0.55 * 1.15, 2))
        + 55 * fieldScale + 20
    // Fire spreads slowly at first, races outward, and slows as it reaches the corners.
    readonly property real spread: sweep * sweep * (2.2 - 1.2 * sweep)
    readonly property real burnR: -20 + spread * (maxRadius + 20)
    // How fast the front moves (px/s), so flames keep up with it: they burn out a
    // seventh of a second's travel behind it, the revealed wallpaper clearing behind them.
    readonly property real frontSpeed: sweep * (4.4 - 3.6 * sweep) * (maxRadius + 20) / spreadTime

    EffectClock {
        id: clock
        onAdvanced: function(dt) {
            if (root.sweep < 1) {
                root.sweep = Math.min(1, root.sweep + dt / root.spreadTime);
                root.tailStart = clock.clock;
                root.shedEmbers(dt);
            } else if (!root.done && clock.clock - root.tailStart >= root.tailTime) {
                root.done = true;
                // Speshell may destroy this item inside the signal, so nothing may follow it.
                root.finished();
            }
        }
    }

    ShaderEffectSource {
        id: outgoingTex
        sourceItem: root.outgoing
        hideSource: true
        live: false
    }

    ShaderEffect {
        anchors.fill: parent
        visible: root.sweep < 1
        property var source: outgoingTex
        property rect rect: Qt.rect(0, 0, width, height)
        property point revealOrigin: root.origin
        property real revealR: 1e5
        property point burnOrigin: root.origin
        property real burnR: root.burnR
        property real refill: 0
        property real fade: 0
        property real fieldScale: root.fieldScale
        property color cGlow: Flame.glow(root.theme)
        property color cHot: root.core
        property color cChar: Flame.charred(root.theme, true)
        property color cScorch: Flame.scorch(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/Burn.qsb")
    }

    Flames {
        theme: root.theme
        anchors.fill: parent
        time: clock.simTime
        // The front burns down as it reaches the corners, so its flames die out with it.
        frontFuel: 1 - 0.75 * Math.max(0, Math.min(1, (root.sweep - 0.7) / 0.3))
        panelRect: Qt.rect(0, 0, root.width, root.height)
        origin: root.origin
        burnR: root.burnR
        fieldScale: root.fieldScale
        clearBehind: false
        trail: 80 + 0.15 * root.frontSpeed
        core: root.core
    }

    // The controls' ember, larger.
    Particles {
        id: embers
        anchors.fill: parent
        capacity: 96
        delegate: Component {
            ShaderEffect {
                property real age: 0
                property real seed: 0
                property real kind: 4
                property real size: width
                property color cCore: Flame.core(root.theme)
                property color cMid: Flame.mid(root.theme)
                property color cOuter: Flame.outer(root.theme)
                property color cEdge: Flame.edge(root.theme)
                property color cSmoke: root.theme ? root.theme.overlay : "#8a5048"
                property color cGlint: root.theme ? root.theme.text : "#f3e3d3"
                fragmentShader: Qt.resolvedUrl("qsb/Interactions.qsb")
            }
        }
    }
}
