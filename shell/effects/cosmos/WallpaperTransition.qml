import QtQuick
import "common"
import "Cosmos.js" as Cosmos

// Cosmos wallpaper transition: a star flares in the middle of the screen and goes
// supernova, its shock front sweeping the old wallpaper away to the new one.
WallpaperStage {
    id: root

    // ── Choreography (seconds) ──────────────────────────────
    readonly property real flareTime: 0.3
    readonly property real sweepTime: 1.3
    duration: flareTime + sweepTime

    // Palette, from the theme.
    readonly property color hot: Cosmos.hot(root.theme)
    readonly property color warm: root.theme.accent
    readonly property color gold: root.theme.yellow
    readonly property color violet: root.theme.pink

    readonly property real flare: Math.min(1, root.clock.clock / root.flareTime)
    readonly property real sweep: Math.max(0, Math.min(1, (root.clock.clock - root.flareTime) / root.sweepTime))
    readonly property point origin: Qt.point(width / 2, height / 2)
    readonly property real maxRadius: Math.sqrt(width * width + height * height) / 2 + 40
    // Bursting out, then slowing as it spreads.
    readonly property real eased: 1 - Math.pow(1 - sweep, 2.2)

    ShaderEffect {
        anchors.fill: parent
        visible: root.sweep < 1
        property var source: root.outgoingTexture
        property rect rect: Qt.rect(0, 0, width, height)
        property rect panel: rect
        property real radius: 0
        property point origin: root.origin
        property real circle: root.eased * root.maxRadius
        property real outside: 1
        property real lens: 40 * (1 - root.sweep * 0.6)
        property real ringWidth: 3
        property real ring: root.sweep > 0 ? 1 - Math.pow(root.sweep, 4) : 0
        property real debris: 1
        property color cHot: root.hot
        property color cGlow: root.warm
        property color cHaze: root.violet
        fragmentShader: Qt.resolvedUrl("qsb/Portal.qsb")
    }

    Glint {
        cx: root.origin.x
        cy: root.origin.y
        size: 520
        spin: 0.2 + root.eased * 0.6
        cHot: root.hot
        cGlow: root.gold
        k: root.sweep === 0 ? root.flare : Math.max(0, 1 - root.sweep * 1.6)
    }
}
