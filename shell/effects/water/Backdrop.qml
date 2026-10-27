import QtQuick

// Water backdrop: the panel seen from under water, with light shafts and
// caustics near the surface, deepening below, and bubbles rising. Drawn once.
ShaderEffect {
    id: root

    // ── Speshell effects API v1: backdrop ────────────────────
    property var theme: null

    property size size: Qt.size(width, height)
    property color cBase: root.theme ? root.theme.bg : "#282828"
    property color cDeep: root.theme ? root.theme.crust : "#1b1b1b"
    property color cText: root.theme ? root.theme.text : "#ebdbb2"
    property color cLight: root.theme ? root.theme.sky : "#83a598"
    fragmentShader: Qt.resolvedUrl("qsb/Backdrop.qsb")
}
