import QtQuick
import "common/Colors.js" as Colors

// Air backdrop: two banks of cloud, threads of wind curling across the
// panel, and a few leaves caught in them. Drawn once.
ShaderEffect {
    id: root

    // ── Speshell effects API v1: backdrop ────────────────────
    property var theme: Colors.fallback

    property size size: Qt.size(width, height)
    property color cBase: root.theme.bg
    property color cDeep: root.theme.crust
    property color cText: root.theme.text
    property color cAccent: root.theme.accent
    property color cLeafBack: root.theme.peach
    fragmentShader: Qt.resolvedUrl("qsb/Backdrop.qsb")
}
