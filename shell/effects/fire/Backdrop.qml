import QtQuick
import "common/Colors.js" as Colors

// Fire backdrop: banked heat glowing up from the bottom edge in flame
// tongues, embers rising off it, and smoke darkening the top. Drawn once.
ShaderEffect {
    id: root

    // ── Speshell effects API v1: backdrop ────────────────────
    property var theme: Colors.fallback

    property size size: Qt.size(width, height)
    property color cBase: root.theme.bg
    property color cDeep: root.theme.crust
    property color cAccent: root.theme.accent
    property color cEmber: root.theme.peach
    property color cFlame: root.theme.error
    fragmentShader: Qt.resolvedUrl("qsb/Backdrop.qsb")
}
