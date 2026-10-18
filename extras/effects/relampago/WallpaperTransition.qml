import QtQuick
import "common"
import "Bolt.js" as Bolt

// Relâmpago wallpaper transition: lightning forks down the screen and splits the old
// wallpaper along its path, and the two halves race off to either side, their torn
// edges glowing, embers spilling into the gap.
Item {
    id: root

    // ── Speshell effects API v1 ────────────────────────────────
    property Item outgoing: null
    // The active palette, as Theme.qml names it.
    property var theme: null
    signal finished()

    readonly property real splitTime: 1.15
    readonly property real tailTime: 0.1

    property real progress: 0
    property real tailStart: 0
    property bool done: false

    EffectClock {
        id: clock
        onAdvanced: function(dt) {
            if (root.progress < 1) {
                root.progress = Math.min(1, root.progress + dt / root.splitTime);
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
        visible: root.progress < 1
        property var source: outgoingTex
        property size resolution: Qt.size(width, height)
        property real progress: root.progress
        property color cCore: Bolt.core(root.theme)
        property color cGlow: Bolt.glow(root.theme)
        property color cEdge: Bolt.edge(root.theme)
        property color cPaint: Bolt.paint(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.qsb")
    }
}
