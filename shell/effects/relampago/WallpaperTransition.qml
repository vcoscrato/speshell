import QtQuick
import "common"
import "Bolt.js" as Bolt

// Relâmpago wallpaper transition: a cartoon bolt strikes down the screen, bursting
// in a starburst where it lands, and splits the old wallpaper along its path; the
// two halves race off to either side, their torn edges inked and glowing, speed
// dashes streaming off them and embers spilling into the gap.
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

    // The bolt's path, its forks, and its embers, worked out once (WallpaperTransition.tear.frag):
    // a texel for each row of the screen and one past it, and room for the 4 forks
    // and 32 embers.
    readonly property int columns: Math.max(Math.ceil(height) + 2, 4 + 2 * 32)
    // How far the halves have split, and the gap between them, as the shader has them.
    readonly property real split: Math.max(0, Math.min(1, (progress - 0.16) / 0.84))
    readonly property real gap: width * 0.72 * Math.pow(split, 2.1)
    readonly property int bands: Math.ceil(height / 16)

    ShaderEffect {
        id: tearPass
        width: root.columns
        height: 2
        blending: false
        property size resolution: Qt.size(root.width, root.height)
        property real seed: transition.seed
        property real columns: root.columns
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.tear.qsb")
    }

    ShaderEffectSource {
        id: tearTex
        sourceItem: tearPass
        hideSource: true
        format: ShaderEffectSource.RGBA32F
        textureSize: Qt.size(root.columns, 2)
    }

    // Which embers reach each band of 16 rows this frame (WallpaperTransition.embers.frag).
    ShaderEffect {
        id: embersPass
        visible: root.split > 0 && root.split < 0.95
        width: root.bands
        height: 16
        blending: false
        property real s: root.split
        property real gap: root.gap
        property var tear: tearTex
        property real columns: root.columns
        property real bands: root.bands
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.embers.qsb")
    }

    ShaderEffectSource {
        id: embersTex
        sourceItem: embersPass
        hideSource: true
        smooth: false
        format: ShaderEffectSource.RGBA32F
        textureSize: Qt.size(root.bands, 16)
    }

    ShaderEffect {
        id: transition
        anchors.fill: parent
        visible: root.progress < 1
        property var source: outgoingTex
        property size resolution: Qt.size(width, height)
        property real progress: root.progress
        readonly property real seed: Math.random()
        property var tear: tearTex
        property var embers: embersTex
        property real columns: root.columns
        property real bands: root.bands
        property color cCore: Bolt.core(root.theme)
        property color cGlow: Bolt.glow(root.theme)
        property color cEdge: Bolt.edge(root.theme)
        property color cPaint: Bolt.paint(root.theme)
        property color cRubber: Bolt.rubber(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.qsb")
    }
}
