import QtQuick
import "Bolt.js" as Bolt

// Relâmpago backdrop: asphalt, a checkered flag in the corner, pinstripes,
// and a forked bolt. Drawn once.
ShaderEffect {
    id: root

    // ── Speshell effects API v1: backdrop ────────────────────
    property var theme: null

    property size size: Qt.size(width, height)
    property color cBase: root.theme ? root.theme.bg : "#19171a"
    property color cDeep: Bolt.rubber(root.theme)
    property color cText: root.theme ? root.theme.text : "#f6eee8"
    property color cPaint: Bolt.paint(root.theme)
    property color cGlow: Bolt.glow(root.theme)
    fragmentShader: Qt.resolvedUrl("qsb/Backdrop.qsb")
}
