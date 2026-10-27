import QtQuick

// Earth's knob for Speshell's sliders and switches: a lopsided stone that rolls as
// it moves, its jade vein brightening while it is held.
ShaderEffect {
    id: root

    // ── Speshell effects API v1: knob ───────────────────────
    property var theme: null
    property bool pressed: false
    property bool hovered: false
    property bool checked: true
    property real travel: 0

    property real size: Math.min(width, height)
    // Rolling without slipping.
    property real turn: root.travel / Math.max(1, root.size / 2)
    property real glow: root.pressed || root.hovered ? 1 : 0
    property real dim: root.checked ? 0 : 1
    property color cStone: root.theme ? root.theme.overlay : "#677052"
    property color cLight: root.theme ? root.theme.subtextBright : "#c6c6ad"
    property color cShade: root.theme ? root.theme.crust : "#0d0f0a"
    property color cJade: root.theme ? root.theme.accent : "#5fa57a"
    property color cGlint: root.theme ? root.theme.text : "#e9e6d3"
    fragmentShader: Qt.resolvedUrl("qsb/Knob.qsb")

    Behavior on glow { NumberAnimation { duration: 150 } }
    Behavior on dim { NumberAnimation { duration: 150 } }
}
