import QtQuick
import "common/Colors.js" as Colors

// Cosmos backdrop: a faint nebula lane across the panel, star dust
// thickest along it, and a few glints. Drawn once.
ShaderEffect {
    id: root

    // ── Speshell effects API v1: backdrop ────────────────────
    property var theme: Colors.fallback

    property size size: Qt.size(width, height)
    property color cBase: root.theme.bg
    property color cDeep: root.theme.crust
    property color cText: root.theme.text
    property color cAccent: root.theme.accent
    fragmentShader: Qt.resolvedUrl("qsb/Backdrop.qsb")
}
