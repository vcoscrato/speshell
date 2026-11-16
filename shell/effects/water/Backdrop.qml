import QtQuick
import "common/Colors.js" as Colors

// Water backdrop: the panel seen from under water, with light shafts and
// caustics near the surface, deepening below, and bubbles rising. Drawn once.
ShaderEffect {
    id: root

    // ── Speshell effects API v1: backdrop ────────────────────
    property var theme: Colors.fallback

    property size size: Qt.size(width, height)
    property color cBase: root.theme.bg
    property color cDeep: root.theme.crust
    property color cText: root.theme.text
    property color cLight: root.theme.sky
    fragmentShader: Qt.resolvedUrl("qsb/Backdrop.qsb")
}
