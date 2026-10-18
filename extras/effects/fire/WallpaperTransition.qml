import QtQuick
import "Flame.js" as Flame
import "common"

// Fire wallpaper transition: the old wallpaper catches near the middle of the screen,
// where the launcher was, and burns away outward to the new one.
Item {
    id: root

    // ── Speshell effects API v1 ────────────────────────────────
    property Item outgoing: null
    // The active palette, as Theme.qml names it.
    property var theme: null
    signal finished()

    // ── Choreography (seconds) ──────────────────────────────
    readonly property real spreadTime: 1.6
    readonly property real tailTime: 0.7       // flames left burning after the front passes
    readonly property real fieldScale: 4

    readonly property color core: Flame.core(root.theme)

    property real sweep: 0
    property real tailStart: 0
    property bool done: false
    readonly property point origin: Qt.point(width * 0.5, height * 0.55)
    // Past this radius the ragged front has cleared every screen corner.
    readonly property real maxRadius: Math.sqrt(Math.pow(width * 0.5 * 0.85, 2) + Math.pow(height * 0.55 * 1.15, 2))
        + 55 * fieldScale + 20
    // Fire spreads slowly at first, then races outward.
    readonly property real burnR: -20 + Math.pow(sweep, 1.4) * (maxRadius + 20)

    EffectClock {
        id: clock
        onAdvanced: function(dt) {
            if (root.sweep < 1) {
                root.sweep = Math.min(1, root.sweep + dt / root.spreadTime);
                root.tailStart = clock.clock;
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
        frontFuel: root.sweep < 1 ? 1 : 0
        panelRect: Qt.rect(0, 0, root.width, root.height)
        origin: root.origin
        burnR: root.burnR
        fieldScale: root.fieldScale
        clearBehind: false
        core: root.core
    }
}
