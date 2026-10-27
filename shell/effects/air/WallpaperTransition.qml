import QtQuick
import "common"
import "common/Colors.js" as Colors

// Air wallpaper transition: a whirlwind eye opens in the middle of the screen and
// widens until the old wallpaper is gone, wringing it into the spin as the wind
// whirls out.
Item {
    id: root

    // ── Speshell effects API v1 ────────────────────────────────
    property Item outgoing: null
    // The active palette, as Theme.qml names it.
    property var theme: null
    signal finished()

    readonly property real spreadTime: 1.3
    readonly property real tailTime: 0.3
    readonly property real spin: 1

    property real sweep: 0
    property real tailStart: 0
    property bool done: false
    readonly property point center: Qt.point(width * 0.5, height * 0.55)
    readonly property real reach: Math.sqrt(Math.pow(width * 0.5, 2) + Math.pow(height * 0.55, 2)) * 1.1 + 40
    // Opens gently, then rushes outward.
    readonly property real eye: Math.pow(sweep, 1.6) * reach

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
        property size resolution: Qt.size(width, height)
        property point center: root.center
        property real eye: root.eye
        // Wrung hardest while the eye is a third open, still turning as it rushes out.
        property real twist: 1.25 * Math.sin(Math.PI * Math.min(1, root.sweep * 1.15))
        property real time: clock.simTime
        property real spin: root.spin
        property color cRim: root.theme ? Colors.mix(root.theme.rosewater, root.theme.sky, 0.25) : "#cfe3f3"
        property color cHaze: root.theme ? root.theme.rosewater : "#e9f2fa"
        property color cGlint: root.theme ? root.theme.text : "#f4ead8"
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.qsb")
    }

    // Wind whirling outward ahead of the eye.
    Wind {
        theme: root.theme
        anchors.fill: parent
        opacity: Math.min(root.sweep / 0.08, 1 - Math.max(0, (root.sweep - 0.75) / 0.25))
        visible: opacity > 0
        time: clock.simTime
        center: root.center
        axes: Qt.size(300, 300)
        source: 24
        vortex: -3 * root.spin
        spacing: 0.1
        dash: 2
        travel: 4 * root.sweep + 0.3 * clock.simTime
        duty: 0.5
        density: 0.45
        lineWidth: 4
        sheet: 0.2
        inner: Math.max(0.2, root.eye / 300 * 0.95)
        outer: Math.max(0.2, root.eye / 300 * 0.95) + 2.6
        mist: 0.8 * Math.sin(Math.PI * root.sweep)
        turbulence: 40
    }

    // Leaves and dust flung outward with the wind.
    Debris {
        theme: root.theme
        opacity: Math.min(root.sweep / 0.1, 1 - Math.max(0, (root.sweep - 0.7) / 0.3))
        visible: opacity > 0
        time: clock.simTime
        center: root.center
        leaves: 12
        dust: 22
        r0: 80 + root.eye * 1.05
        spin: root.spin
        head: root.sweep * 7 + clock.simTime * 0.5
        leafSize: 18
        turbulence: 20
    }
}
