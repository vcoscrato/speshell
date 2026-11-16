import QtQuick
import "Water.js" as Water
import "common"

// Water launcher transition: a whip of water spirals in to the middle of the
// launcher and spreads into a sheet in its shape; the water clears to leave the
// launcher, and two streams keep circling it while it is open, among orbs, currents,
// and mist held in the air. Closing turns it back to water, draws it into an orb,
// and whips away.
LauncherStage {
    id: root

    // ── Choreography (seconds) ──────────────────────────────
    enterTime: 1.0
    exitTime: 0.65
    tailTime: 0.1

    readonly property point center: Qt.point(panelRect.x + panelRect.width / 2, panelRect.y + panelRect.height / 2)
    readonly property real reach: Math.sqrt(panelRect.width * panelRect.width + panelRect.height * panelRect.height) / 2
    readonly property real pad: 40

    function ease(x) { return 1 - Math.pow(1 - Math.max(0, Math.min(1, x)), 3); }
    function span(x, a, b) { return Math.max(0, Math.min(1, (x - a) / (b - a))); }
    function smooth(x) { return x * x * (3 - 2 * x); }

    readonly property real grow: leave > 0 ? 1 - ease(span(leave, 0.25, 0.75)) : ease(span(enter, 0.36, 0.75))
    // Streams circling the open launcher: drawn out of the sheet as it clears, and
    // pulled back in as the launcher turns to water again.
    readonly property real flow: leave > 0 ? 1 - span(leave, 0, 0.3) : ease(span(enter, 0.7, 1))
    readonly property real settle: leave > 0 ? 1 - ease(span(leave, 0, 0.35)) : ease(span(enter, 0.62, 1))

    // ── Arriving whip: spirals in to the middle, then its tail drains in after it ──
    Whip {
        theme: root.theme
        readonly property real k0: 0.2
        readonly property real startR: root.reach * 3.4
        readonly property real arrive: Math.log(startR / 22) / k0
        readonly property real fullLen: 5
        anchors.fill: parent
        visible: root.leave === 0 && root.enter < 0.7
        time: root.clock.simTime
        center: root.center
        r0: startR
        k: k0
        th0: 2.4
        spin: 1
        // Eased in and out only gently, so it never races or stalls.
        head: (0.5 * root.span(root.enter, 0, 0.46) + 0.5 * root.smooth(root.span(root.enter, 0, 0.46))) * arrive
        len: fullLen * (1 - root.smooth(root.span(root.enter, 0.4, 0.68)))
        tubeWidth: 24
    }

    // ── Departing whip: unwinds out of the orb ──
    Whip {
        theme: root.theme
        anchors.fill: parent
        visible: root.leave > 0.55
        time: root.clock.simTime
        center: root.center
        r0: 22
        k: -0.2
        th0: -0.7
        spin: 1
        // Gathering speed as it leaves, so it is seen unwinding before it whips away.
        head: Math.pow(root.span(root.leave, 0.55, 1), 1.7) * (Math.log(root.reach * 3.4 / 22) / 0.2 + 5)
        len: Math.min(5, head)
        tubeWidth: 24
    }

    // ── The panel as a sheet of water; otherwise the real panel shows ──
    ShaderEffect {
        visible: root.capturing && root.panel !== null && root.grow > 0
        x: root.panelRect.x - root.pad
        y: root.panelRect.y - root.pad
        width: root.panelRect.width + 2 * root.pad
        height: root.panelRect.height + 2 * root.pad
        property var source: root.panelTexture
        property real time: root.clock.simTime
        property rect rect: Qt.rect(x, y, width, height)
        property rect panel: root.panelRect
        property real radius: root.panelRadius
        property real grow: root.grow
        property real settle: root.settle
        property color cDeep: Water.deep(root.theme)
        property color cMid: Water.mid(root.theme)
        property color cLight: Water.light(root.theme)
        property color cFoam: Water.foam(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.qsb")
    }

    // Where the glints and orbs held round the launcher are this frame.
    ShaderEffect {
        id: motesPass
        visible: root.flow > 0
        width: 31
        height: 2
        blending: false
        property real time: root.clock.simTime
        property rect panel: root.panelRect
        property real radius: root.panelRadius
        property real flow: root.flow
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.motes.qsb")
    }

    ShaderEffectSource {
        id: motesTex
        sourceItem: motesPass
        hideSource: true
        smooth: false
        format: ShaderEffectSource.RGBA32F
        textureSize: Qt.size(31, 2)
    }

    // Water held in the air around the open launcher, behind the streams.
    ShaderEffect {
        readonly property real margin: 240
        visible: root.flow > 0
        x: root.panelRect.x - margin
        y: root.panelRect.y - margin
        width: root.panelRect.width + 2 * margin
        height: root.panelRect.height + 2 * margin
        property real time: root.clock.simTime
        property rect rect: Qt.rect(x, y, width, height)
        property rect panel: root.panelRect
        property real radius: root.panelRadius
        property real flow: root.flow
        property var motes: motesTex
        property color cDeep: Water.deep(root.theme)
        property color cMid: Water.mid(root.theme)
        property color cLight: Water.light(root.theme)
        property color cFoam: Water.foam(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.held.qsb")
    }

    // Where the streams' droplets are this frame, worked out once for every pixel.
    ShaderEffect {
        id: dropsPass
        visible: root.flow > 0
        width: 36
        height: 2
        blending: false
        property real time: root.clock.simTime
        property rect panel: root.panelRect
        property real radius: root.panelRadius
        property real gap: 15
        property real flow: root.flow
        property real speed: 170
        property real tubeWidth: 10
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.drops.qsb")
    }

    ShaderEffectSource {
        id: dropsTex
        sourceItem: dropsPass
        hideSource: true
        smooth: false
        format: ShaderEffectSource.RGBA32F
        textureSize: Qt.size(36, 2)
    }

    ShaderEffect {
        readonly property real margin: 120
        visible: root.flow > 0
        x: root.panelRect.x - margin
        y: root.panelRect.y - margin
        width: root.panelRect.width + 2 * margin
        height: root.panelRect.height + 2 * margin
        property real time: root.clock.simTime
        property rect rect: Qt.rect(x, y, width, height)
        property rect panel: root.panelRect
        property real radius: root.panelRadius
        property real gap: 15
        property real flow: root.flow
        property real speed: 170
        property real tubeWidth: 10
        property var dropTable: dropsTex
        property color cDeep: Water.deep(root.theme)
        property color cMid: Water.mid(root.theme)
        property color cLight: Water.light(root.theme)
        property color cFoam: Water.foam(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.stream.qsb")
    }
}
