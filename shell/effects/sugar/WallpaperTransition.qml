import QtQuick
import "common"
import "Sugar.js" as Sugar

// Sugar wallpaper transition: a curtain of glaze pours down over the old wallpaper,
// its drips running ahead and drops falling off them, and slides off the bottom with
// the old wallpaper, leaving the new one above it.
WallpaperStage {
    id: root

    readonly property real pourTime: 1.7
    duration: pourTime + 0.1

    readonly property real progress: Math.min(1, root.clock.clock / root.pourTime)

    ShaderEffect {
        anchors.fill: parent
        visible: root.progress < 1
        property var source: root.outgoingTexture
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
