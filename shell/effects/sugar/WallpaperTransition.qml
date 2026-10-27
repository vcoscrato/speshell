import QtQuick
import "common"
import "Sugar.js" as Sugar

// Sugar wallpaper transition: a curtain of glaze pours down over the old wallpaper,
// its drips running ahead and drops falling off them, and slides off the bottom with
// the old wallpaper, leaving the new one above it.
Item {
    id: root

    // ── Speshell effects API v1 ────────────────────────────────
    property Item outgoing: null
    // The active palette, as Theme.qml names it.
    property var theme: null
    signal finished()

    readonly property real pourTime: 1.7
    readonly property real tailTime: 0.1

    property real progress: 0
    property real tailStart: 0
    property bool done: false

    EffectClock {
        id: clock
        onAdvanced: function(dt) {
            if (root.progress < 1) {
                root.progress = Math.min(1, root.progress + dt / root.pourTime);
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
        readonly property real seed: Math.random()
        property color cInk: Sugar.ink(root.theme)
        property color cFrost: Sugar.frosting(root.theme)
        property color cFrostLight: Sugar.frostingLight(root.theme)
        property color cFrostShade: Sugar.frostingShade(root.theme)
        property color cFilm: Sugar.sparkle(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.qsb")
    }
}
