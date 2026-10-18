import QtQuick
import "Stone.js" as Stone
import "common"

// Earth launcher transition: the ground cracks open below the launcher and the
// launcher rises out of it as a stone slab, flinging rock chips and dust, and
// lands with a jolt as the stone falls away. Boulders rise after it and hover around
// the launcher while it is open. Closing drops them and sinks the launcher back into
// the ground.
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
    readonly property real enterTime: 0.95
    readonly property real exitTime: 0.6
    readonly property real tailTime: 0.25

    property real enter: 0
    property real leave: 0
    property real tailStart: 0
    property bool exitDone: false

    readonly property real ground: panelRect.y + panelRect.height
    readonly property real depth: panelRect.height + 24
    readonly property bool capturing: enter < 1 || leave > 0
    readonly property real pad: 30

    function span(x, a, b) { return Math.max(0, Math.min(1, (x - a) / (b - a))); }
    // Overshoots slightly before settling, like a slab punched up.
    function backOut(x) { var c = 1.9; return 1 + (c + 1) * Math.pow(x - 1, 3) + c * Math.pow(x - 1, 2); }

    readonly property real rise: leave > 0
        ? Math.pow(span(leave, 0.2, 0.85), 2) * depth
        : (1 - backOut(span(enter, 0.12, 0.55))) * depth
    readonly property real stone: leave > 0 ? span(leave, 0, 0.2) : 1 - span(enter, 0.62, 0.95)
    // A short sideways jolt on landing.
    readonly property real jolt: leave > 0 ? 0 : 5 * Math.sin(span(enter, 0.55, 0.72) * Math.PI * 4) * (1 - span(enter, 0.55, 0.72))
    readonly property real crackOpen: leave > 0
        ? Math.min(span(leave, 0, 0.15), 1 - span(leave, 0.85, 1))
        : Math.min(span(enter, 0, 0.12), 1 - span(enter, 0.65, 0.95))
    readonly property real crackLen: (panelRect.width / 2 + 40) * (leave > 0 ? 1 : span(enter, 0, 0.18))
    readonly property real burstAt: 0.12
    property real burst: -1
    // Boulders: rise once the slab has landed, drop first when it closes.
    readonly property real lift: span(enter, 0.5, 1)
    readonly property real fall: span(leave, 0, 0.55)
    readonly property real dust: leave > 0 ? span(leave, 0.2, 1) : span(enter, 0.12, 1)

    onActiveChanged: exitDone = false

    EffectClock {
        id: clock
        onAdvanced: function(dt) {
            if (root.active) {
                if (root.leave > 0) {
                    root.leave = Math.max(0, root.leave - dt / root.exitTime);
                    return;
                }
                root.enter = Math.min(1, root.enter + dt / root.enterTime);
                if (root.enter >= root.burstAt)
                    root.burst = root.burst < 0 ? 0 : root.burst + dt;
            } else if (root.leave < 1) {
                root.leave = Math.min(1, root.leave + dt / root.exitTime);
                root.tailStart = clock.clock;
            } else if (!root.exitDone && clock.clock - root.tailStart >= root.tailTime) {
                root.exitDone = true;
                // Speshell may destroy this item inside the signal, so nothing may follow it.
                root.closingFinished();
            }
        }
    }

    // ── The panel as a rising slab; otherwise the real panel shows ──
    ShaderEffectSource {
        id: panelTex
        sourceItem: root.panel
        hideSource: root.capturing
        live: root.capturing
    }

    ShaderEffect {
        visible: root.capturing && root.panel !== null
        x: root.panelRect.x - root.pad
        y: root.panelRect.y - root.pad
        width: root.panelRect.width + 2 * root.pad
        height: root.panelRect.height + 2 * root.pad
        property var source: panelTex
        property rect rect: Qt.rect(x, y, width, height)
        property rect panel: root.panelRect
        property real radius: 10
        property real ground: root.ground
        property point offset: Qt.point(root.jolt, root.rise)
        property real stone: root.stone
        property color cLight: Stone.tone(root.theme, "subtext", 0.25, "#a8977a")
        property color cMid: Stone.tone(root.theme, "overlay", 0.15, "#7d6c55")
        property color cDark: Stone.tone(root.theme, "card", 0.25, "#4d4133")
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.qsb")
    }

    // Crack, dust, and chips stay in a band around the ground line.
    ShaderEffect {
        x: root.panelRect.x - 260
        y: root.ground - 300
        width: root.panelRect.width + 520
        height: 380
        visible: root.capturing || root.dust < 1
        property size resolution: Qt.size(width, height)
        property point offset: Qt.point(x, y)
        property point origin: Qt.point(root.panelRect.x + root.panelRect.width / 2, root.ground)
        property real crackLen: root.crackLen
        property real crackOpen: root.crackOpen
        property real burst: root.leave > 0 ? -1 : root.burst
        property real dust: root.dust
        property real spread: root.panelRect.width / 2
        property color cDust: Stone.tone(root.theme, "subtextBright", 0.25, "#cdbb9a")
        property color cDustShade: Stone.tone(root.theme, "overlay", 0.5, "#9c8a6c")
        property color cRock: Stone.tone(root.theme, "overlay", 0.3, "#8a7a62")
        property color cDark: Stone.tone(root.theme, "bg", 0.1, "#2e261d")
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.ground.qsb")
    }

    ShaderEffect {
        readonly property real margin: 240
        visible: root.lift > 0 && root.fall < 1
        x: root.panelRect.x - margin
        y: root.panelRect.y - margin
        width: root.panelRect.width + 2 * margin
        height: root.panelRect.height + 2 * margin
        property real time: clock.simTime
        property rect rect: Qt.rect(x, y, width, height)
        property rect panel: root.panelRect
        property real ground: root.ground
        property real lift: root.lift
        property real fall: root.fall
        property color cLight: Stone.tone(root.theme, "subtext", 0.2, "#b9a888")
        property color cMid: Stone.tone(root.theme, "overlay", 0.3, "#8a7a62")
        property color cDark: Stone.tone(root.theme, "surface2", 0.15, "#5a4c3b")
        property color cEdge: Stone.tone(root.theme, "bg", 0.1, "#2e261d")
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.boulders.qsb")
    }
}
