import QtQuick
import "common/Colors.js" as Colors
import "Bolt.js" as Bolt

// Relâmpago backdrop: asphalt, a checkered flag in the corner, pinstripes,
// and a forked bolt. Drawn once.
ShaderEffect {
    id: root

    // ── Speshell effects API v1: backdrop ────────────────────
    property var theme: Colors.fallback

    property size size: Qt.size(width, height)
    property color cBase: root.theme.bg
    property color cDeep: Bolt.rubber(root.theme)
    property color cText: root.theme.text
    property color cPaint: Bolt.paint(root.theme)
    property color cGlow: Bolt.glow(root.theme)
    fragmentShader: Qt.resolvedUrl("qsb/Backdrop.qsb")
}
