import QtQuick
import "Water.js" as Water
import "common"

// Water launcher transition: a whip of water spirals in to the middle of the
// launcher and spreads into a sheet in its shape; the water clears to leave the
// launcher, and two streams keep circling it while it is open, among orbs, currents,
// and mist held in the air. Closing turns it back to water, draws it into an orb,
// and whips away.
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
    readonly property real exitTime: 0.65
    readonly property real tailTime: 0.1

    property real enter: 0
    property real leave: 0
    property real tailStart: 0
    property bool exitDone: false

    readonly property point center: Qt.point(panelRect.x + panelRect.width / 2, panelRect.y + panelRect.height / 2)
    readonly property real reach: Math.sqrt(panelRect.width * panelRect.width + panelRect.height * panelRect.height) / 2
    readonly property bool capturing: enter < 1 || leave > 0
    readonly property real pad: 40

    function ease(x) { return 1 - Math.pow(1 - Math.max(0, Math.min(1, x)), 3); }
    function span(x, a, b) { return Math.max(0, Math.min(1, (x - a) / (b - a))); }
    function smooth(x) { return x * x * (3 - 2 * x); }

    readonly property real grow: leave > 0 ? 1 - ease(span(leave, 0.25, 0.75)) : ease(span(enter, 0.36, 0.75))
    // Streams circling the open launcher: drawn out of the sheet as it clears, and
    // pulled back in as the launcher turns to water again.
    readonly property real flow: leave > 0 ? 1 - span(leave, 0, 0.3) : ease(span(enter, 0.7, 1))
    readonly property real settle: leave > 0 ? 1 - ease(span(leave, 0, 0.35)) : ease(span(enter, 0.62, 1))

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

    // ── Arriving whip: spirals in to the middle, then its tail drains in after it ──
    Whip {
        theme: root.theme
        readonly property real k0: 0.2
        readonly property real startR: root.reach * 3.4
        readonly property real arrive: Math.log(startR / 22) / k0
        readonly property real fullLen: 5
        anchors.fill: parent
        visible: root.leave === 0 && root.enter < 0.7
        time: clock.simTime
        center: root.center
        r0: startR
        k: k0
        th0: 2.4
        spin: 1
        head: root.smooth(root.span(root.enter, 0, 0.42)) * arrive
        len: fullLen * (1 - root.span(root.enter, 0.42, 0.66))
        tubeWidth: 24
    }

    // ── Departing whip: unwinds out of the orb ──
    Whip {
        theme: root.theme
        anchors.fill: parent
        visible: root.leave > 0.55
        time: clock.simTime
        center: root.center
        r0: 22
        k: -0.2
        th0: -0.7
        spin: 1
        head: root.ease(root.span(root.leave, 0.55, 1)) * (Math.log(root.reach * 3.4 / 22) / 0.2 + 5)
        len: Math.min(5, head)
        tubeWidth: 24
    }

    // ── The panel as a sheet of water; otherwise the real panel shows ──
    ShaderEffectSource {
        id: panelTex
        sourceItem: root.panel
        hideSource: root.capturing
        live: root.capturing
    }

    ShaderEffect {
        visible: root.capturing && root.panel !== null && root.grow > 0
        x: root.panelRect.x - root.pad
        y: root.panelRect.y - root.pad
        width: root.panelRect.width + 2 * root.pad
        height: root.panelRect.height + 2 * root.pad
        property var source: panelTex
        property real time: clock.simTime
        property rect rect: Qt.rect(x, y, width, height)
        property rect panel: root.panelRect
        property real radius: 10
        property real grow: root.grow
        property real settle: root.settle
        property color cDeep: Water.deep(root.theme)
        property color cMid: Water.mid(root.theme)
        property color cLight: Water.light(root.theme)
        property color cFoam: Water.foam(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.qsb")
    }

    // Water held in the air around the open launcher, behind the streams.
    ShaderEffect {
        readonly property real margin: 240
        visible: root.flow > 0
        x: root.panelRect.x - margin
        y: root.panelRect.y - margin
        width: root.panelRect.width + 2 * margin
        height: root.panelRect.height + 2 * margin
        property real time: clock.simTime
        property rect rect: Qt.rect(x, y, width, height)
        property rect panel: root.panelRect
        property real radius: 10
        property real flow: root.flow
        property color cDeep: Water.deep(root.theme)
        property color cMid: Water.mid(root.theme)
        property color cLight: Water.light(root.theme)
        property color cFoam: Water.foam(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.held.qsb")
    }

    ShaderEffect {
        readonly property real margin: 120
        visible: root.flow > 0
        x: root.panelRect.x - margin
        y: root.panelRect.y - margin
        width: root.panelRect.width + 2 * margin
        height: root.panelRect.height + 2 * margin
        property real time: clock.simTime
        property rect rect: Qt.rect(x, y, width, height)
        property rect panel: root.panelRect
        property real radius: 10
        property real gap: 15
        property real flow: root.flow
        property real speed: 170
        property real tubeWidth: 10
        property color cDeep: Water.deep(root.theme)
        property color cMid: Water.mid(root.theme)
        property color cLight: Water.light(root.theme)
        property color cFoam: Water.foam(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.stream.qsb")
    }
}
