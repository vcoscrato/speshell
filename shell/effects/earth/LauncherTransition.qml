import QtQuick
import "Stone.js" as Stone
import "common/Colors.js" as Colors
import "common"

// Earth launcher transition: the ground cracks open below the launcher and the
// launcher punches up out of it as a stone slab, flinging rock chips and dust; it
// lands with a jolt that cracks it, and its stone breaks off from there outward to
// leave the panel.
// Boulders rise after it and hover around the launcher while it is open. Closing
// drops them, pulls the stone back over the panel, and sinks the slab back into the
// ground.
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
    readonly property real enterTime: 1.0
    readonly property real exitTime: 0.7
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

    // Entrance: the ground cracks (0-0.1), the slab punches up and overshoots
    // (0.08-0.37), lands with a jolt that cracks it (0.37-0.5), and its shell breaks
    // off from where it landed outward (0.42-1). Exit: the chunks fly back (0-0.25),
    // then it sinks, slowly at first (0.22-0.85).
    readonly property real rise: leave > 0
        ? Math.pow(span(leave, 0.22, 0.85), 2) * depth
        : (1 - backOut(span(enter, 0.08, 0.37))) * depth
    readonly property real cracks: leave > 0 ? 1 : span(enter, 0.37, 0.5)
    readonly property real crumble: leave > 0 ? 1 - span(leave, 0, 0.25) : span(enter, 0.42, 1)
    // A short sideways jolt on landing.
    readonly property real jolt: leave > 0 ? 0 : 4 * Math.sin(span(enter, 0.37, 0.5) * Math.PI * 4) * (1 - span(enter, 0.37, 0.5))
    readonly property real crackOpen: leave > 0
        ? Math.min(span(leave, 0.15, 0.3), 1 - span(leave, 0.88, 1))
        : Math.min(span(enter, 0, 0.1), 1 - span(enter, 0.48, 0.75))
    readonly property real crackLen: (panelRect.width / 2 + 40) * (leave > 0 ? 1 : span(enter, 0, 0.14))
    readonly property real burstAt: 0.08
    property real burst: -1
    // Boulders: rise once the slab has landed, drop first when it closes.
    readonly property real lift: span(enter, 0.4, 1)
    readonly property real fall: span(leave, 0, 0.55)
    readonly property real dust: leave > 0 ? span(leave, 0.22, 1) : span(enter, 0.08, 1)

    // The slab's stone: one ramp of the theme's neutrals, warmed a little.
    readonly property color slabLight: Stone.tone(root.theme, "subtextBright", 0.2, "#c9c0a0")
    readonly property color slabMid: root.theme ? Colors.mix(Colors.mix(root.theme.surface2, root.theme.subtext, 0.42), root.theme.peach, 0.12) : "#6e705a"
    readonly property color slabDark: Stone.tone(root.theme, "cardHover", 0.12, "#343527")

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
        property real cracks: root.cracks
        property real crumble: root.crumble
        property color cLight: root.slabLight
        property color cMid: root.slabMid
        property color cDark: root.slabDark
        property color cEdge: Stone.tone(root.theme, "crust", 0.1, "#15130e")
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
        property color cDust: Colors.mix(root.slabMid, root.slabLight, 0.55)
        property color cDustShade: root.slabMid
        property color cRock: root.slabMid
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
        property color cLight: root.slabLight
        property color cMid: root.slabMid
        property color cDark: root.slabDark
        property color cEdge: Stone.tone(root.theme, "crust", 0.1, "#15130e")
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.boulders.qsb")
    }
}
