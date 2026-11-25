import QtQuick
import "common/Colors.js" as Colors
import "Natal.js" as Natal

// Natal backdrop: a winter pine night. Low down, snow-laden firs at two depths on a
// far snowfield, one hung with a string of warm lights, and a snow bank along the
// bottom; a few still snowflakes in the air. Drawn once.
ShaderEffect {
    id: root

    // ── Speshell effects API v1: backdrop ────────────────────
    property var theme: Colors.fallback

    property size size: Qt.size(width, height)
    property color cBase: root.theme.bg
    property color cDeep: root.theme.crust
    property color cIce: Natal.ice(root.theme)
    property color cSnow: Natal.snow(root.theme)
    property color cSnowShade: Natal.snowShade(root.theme)
    property color cPine: Natal.pineDeep(root.theme)
    property color cGold: Natal.gold(root.theme)
    property color cGlow: Natal.glow(root.theme)
    property color cBerry: Natal.berry(root.theme)
    fragmentShader: Qt.resolvedUrl("qsb/Backdrop.qsb")
}
