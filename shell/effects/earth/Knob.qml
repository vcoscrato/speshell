import QtQuick
import "common/Colors.js" as Colors

// Earth's knob for Speshell's sliders and switches: a lopsided stone that rolls as
// it moves, its jade vein brightening while it is held.
ShaderEffect {
    id: root

    // ── Speshell effects API v1: knob ───────────────────────
    property var theme: Colors.fallback
    property bool pressed: false
    property bool hovered: false
    property bool checked: true
    property real travel: 0

    property real size: Math.min(width, height)
    // Rolling without slipping.
    property real turn: root.travel / Math.max(1, root.size / 2)
    property real glow: root.pressed || root.hovered ? 1 : 0
    property real dim: root.checked ? 0 : 1
    property color cStone: root.theme.overlay
    property color cLight: root.theme.subtextBright
    property color cShade: root.theme.crust
    property color cJade: root.theme.accent
    property color cGlint: root.theme.text
    fragmentShader: Qt.resolvedUrl("qsb/Knob.qsb")

    Behavior on glow { NumberAnimation { duration: 150 } }
    Behavior on dim { NumberAnimation { duration: 150 } }
}
