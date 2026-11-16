import QtQuick
import "common/Colors.js" as Colors

// Earth backdrop: the panel as a cut through layered rock, cracked here
// and there, with pebbles in it. Drawn once.
ShaderEffect {
    id: root

    // ── Speshell effects API v1: backdrop ────────────────────
    property var theme: Colors.fallback

    property size size: Qt.size(width, height)
    property color cBase: root.theme.bg
    property color cDeep: root.theme.crust
    property color cText: root.theme.text
    fragmentShader: Qt.resolvedUrl("qsb/Backdrop.qsb")
}
