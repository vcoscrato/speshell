import QtQuick

// Fire backdrop: banked heat glowing up from the bottom edge in flame
// tongues, embers rising off it, and smoke darkening the top. Drawn once.
ShaderEffect {
    id: root

    // ── Speshell effects API v1: backdrop ────────────────────
    property var theme: null

    property size size: Qt.size(width, height)
    property color cBase: root.theme ? root.theme.bg : "#282828"
    property color cDeep: root.theme ? root.theme.crust : "#1b1b1b"
    property color cAccent: root.theme ? root.theme.accent : "#fe8019"
    property color cEmber: root.theme ? root.theme.peach : "#fe8019"
    property color cFlame: root.theme ? root.theme.error : "#fb4934"
    fragmentShader: Qt.resolvedUrl("qsb/Backdrop.qsb")
}
