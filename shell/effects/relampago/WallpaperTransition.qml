import QtQuick
import "common"
import "Bolt.js" as Bolt

// Relâmpago wallpaper transition: a fat cartoon bolt strikes down the screen, the
// picture jolts through a two-tone impact frame and a flash, a starburst bursts
// where it lands, and the old wallpaper splits along its path; arcs snap across the
// gap as the two halves are flung off to either side, tipping outward, their torn
// edges inked, scorched, and glowing, speed lines streaming off them and sparks
// spilling into the gap.
WallpaperStage {
    id: root

    readonly property real splitTime: 1.15
    duration: splitTime + 0.1

    readonly property real progress: Math.min(1, root.clock.clock / root.splitTime)

    // The bolt's path, its forks, and its embers, worked out once (WallpaperTransition.tear.frag):
    // a texel for each row of the screen and one past it, and room for the 4 forks
    // and 32 embers, two texels each.
    readonly property int columns: Math.max(Math.ceil(height) + 2, 2 * 4 + 2 * 32)
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
        smooth: false
        format: ShaderEffectSource.RGBA32F
        textureSize: Qt.size(root.columns, 2)
    }

    // Which embers reach each band of 16 rows this frame (WallpaperTransition.embers.frag).
    ShaderEffect {
        id: embersPass
        visible: root.split > 0 && root.split < 0.32
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
        property var source: root.outgoingTexture
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
