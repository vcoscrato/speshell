import QtQuick
import "common"

// Air launcher transition: a whirlpool of wind draws in to the launcher, which
// unwinds out of the vortex into place. While open, a breeze parts around it and
// circles it. Closing winds the panel back into the vortex as the wind turns
// outward and blows away.
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
    readonly property real exitTime: 0.5
    readonly property real tailTime: 0.12

    // enter: 0..1 entrance progress; leave: 0..1 exit progress.
    property real enter: 0
    property real leave: 0
    property real tailStart: 0
    property bool exitDone: false

    readonly property point center: Qt.point(panelRect.x + panelRect.width / 2, panelRect.y + panelRect.height / 2)
    readonly property real reach: Math.sqrt(panelRect.width * panelRect.width + panelRect.height * panelRect.height) / 2
    readonly property real spin: 1
    readonly property bool capturing: enter < 1 || leave > 0

    function ease(x) { return 1 - Math.pow(1 - Math.max(0, Math.min(1, x)), 3); }
    function span(x, a, b) { return Math.max(0, Math.min(1, (x - a) / (b - a))); }

    // The panel is wound up while the wind arrives, and unwinds as it settles.
    readonly property real wind: Math.max(1 - ease(span(enter, 0.3, 1)), ease(span(leave, 0, 0.8)))

    onActiveChanged: exitDone = false

    EffectClock {
        id: clock
        onAdvanced: function(dt) {
            if (root.active) {
                // Reopened mid-exit: the panel unwinds back out first.
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

    // ── Arriving wind: a whirlpool of air drawing in from far out to the launcher ──
    Wind {
        theme: root.theme
        anchors.fill: parent
        opacity: root.span(root.enter, 0, 0.15) * (1 - root.span(root.enter, 0.7, 1))
        visible: opacity > 0 && root.leave === 0
        time: clock.simTime
        center: root.center
        axes: Qt.size(root.reach, root.reach)
        source: -24
        vortex: -3 * root.spin
        spacing: 0.1
        dash: 2
        travel: 3 * root.ease(root.enter) + 0.3 * clock.simTime
        duty: 0.5
        density: 0.45
        lineWidth: 3
        sheet: 0.2
        inner: 0.75
        outer: 3.2
        mist: 0.6
        turbulence: 30
    }

    // ── Breeze while open: wind parting around the launcher and circling it,
    //    slowly veering and gusting ──
    Wind {
        theme: root.theme
        readonly property size ext: Qt.size(axes.width * outer + 20, axes.height * outer + 20)
        x: root.center.x - ext.width
        y: root.center.y - ext.height
        width: 2 * ext.width
        height: 2 * ext.height
        opacity: root.span(root.enter, 0.7, 1) * (1 - root.span(root.leave, 0, 0.3))
        visible: opacity > 0
        time: clock.simTime
        center: root.center
        axes: Qt.size(root.panelRect.width * 0.725, root.panelRect.height * 0.725)
        wind: 1
        windAngle: 0.6 + 0.05 * clock.simTime + 0.4 * Math.sin(0.25 * clock.simTime)
        obstacle: 1
        vortex: -1 * root.spin
        spacing: 0.08
        dash: 2.6
        travel: clock.simTime * 0.22 + 0.1 * Math.sin(clock.simTime * 0.8)
        duty: 0.4
        density: 0.3
        lineWidth: 2.8
        sheet: 0.16
        inner: 1
        outer: 1.8
        mist: 0.7
        turbulence: 35
        mask: root.panelRect
    }

    // ── Leaves and dust: whirled in with the wind, carried around while open,
    //    and flung off as the launcher closes ──
    Debris {
        theme: root.theme
        opacity: root.span(root.enter, 0, 0.15) * (1 - root.span(root.leave, 0.5, 1))
        visible: opacity > 0
        time: clock.simTime
        center: root.center
        leaves: 7
        dust: 10
        r0: root.reach * 1.1 * (1 + 1.6 * (1 - root.ease(root.span(root.enter, 0, 0.9))) + 2.2 * root.ease(root.leave))
        spin: root.spin
        head: clock.simTime * 0.9 + 2.5 * root.ease(root.enter) + 3 * root.ease(root.leave)
        leafSize: 15
        turbulence: 14
        mask: root.panelRect
    }

    // ── Departing wind: the whirlpool turns outward and blows away ──
    Wind {
        theme: root.theme
        anchors.fill: parent
        opacity: root.span(root.leave, 0, 0.15) * (1 - root.span(root.leave, 0.6, 1))
        visible: opacity > 0
        time: clock.simTime
        center: root.center
        axes: Qt.size(root.reach, root.reach)
        source: 24
        vortex: -3 * root.spin
        spacing: 0.1
        dash: 2
        travel: 3 * root.ease(root.leave) + 0.3 * clock.simTime
        duty: 0.5
        density: 0.45
        lineWidth: 3
        sheet: 0.2
        inner: 0.5 + 1.2 * root.leave
        outer: 3.2
        mist: 0.6 * Math.sin(Math.PI * root.leave)
        turbulence: 30
    }

    // ── The panel, wound into the vortex; otherwise the real panel shows ──
    ShaderEffectSource {
        id: panelTex
        sourceItem: root.panel
        hideSource: root.capturing
        live: root.capturing
    }

    ShaderEffect {
        visible: root.capturing && root.panel !== null
        x: root.panelRect.x
        y: root.panelRect.y
        width: root.panelRect.width
        height: root.panelRect.height
        property var source: panelTex
        property rect rect: root.panelRect
        property point center: root.center
        property real wind: root.wind
        property real spin: root.spin
        property real reach: root.reach
        property color cRing: root.theme ? root.theme.rosewater : "#eef5fb"
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.qsb")
    }
}
