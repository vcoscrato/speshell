import QtQuick
import "common"
import "common/Colors.js" as Colors
import "Water.js" as Water

// Water wallpaper transition: a drop lands in the middle of the screen, splashing a
// crown and a jet, and its ripple spreads out, carrying the new wallpaper in behind it.
WallpaperStage {
    id: root

    readonly property real spreadTime: 1.5
    readonly property real calmTime: 0.6
    duration: spreadTime + calmTime

    readonly property real sweep: Math.min(1, root.clock.clock / root.spreadTime)
    readonly property real calm: Math.max(0, Math.min(1, (root.clock.clock - root.spreadTime) / root.calmTime))
    readonly property point center: Qt.point(width * 0.5, height * 0.55)
    readonly property real reach: Math.sqrt(Math.pow(width * 0.5, 2) + Math.pow(height * 0.55, 2)) + 120

    ShaderEffectSource {
        id: incomingTex
        sourceItem: root.incoming
        hideSource: true
        live: false
    }

    ShaderEffect {
        anchors.fill: parent
        property var outgoingTex: root.outgoingTexture
        property var incomingTex: incomingTex
        property size resolution: Qt.size(width, height)
        property point center: root.center
        // Ripples slow as they spread.
        property real ring: (1 - Math.pow(1 - root.sweep, 1.6)) * root.reach
        property real strength: 21 * (1 - 0.5 * root.sweep)
        property real calm: Math.max(root.calm, root.sweep > 0.85 ? (root.sweep - 0.85) / 0.6 : 0)
        property real age: root.sweep * root.spreadTime
        property color cLight: root.theme.text
        property color cDark: Colors.mix(root.theme.crust, root.theme.accent, 0.3)
        property color cWater: Water.mid(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.qsb")
    }
}
