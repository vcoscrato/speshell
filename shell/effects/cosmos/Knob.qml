import QtQuick
import "common/Colors.js" as Colors

// Cosmos's knob for Speshell's sliders and switches: a banded planet whose moon
// orbits as it travels, ringed while held or hovered.
Item {
    id: root

    // ── Speshell effects API v1: knob ───────────────────────
    property var theme: Colors.fallback
    property bool pressed: false
    property bool hovered: false
    property bool checked: true
    property real travel: 0

    readonly property real size: Math.min(width, height)
    property real glow: root.pressed || root.hovered ? 1 : 0

    Behavior on glow { NumberAnimation { duration: 150 } }

    ShaderEffect {
        anchors.centerIn: parent
        width: root.size * 2.4
        height: root.size * 2.4
        property size area: Qt.size(width, height)
        property real size: root.size
        property real turn: root.travel / Math.max(1, root.size / 2)
        property real glow: root.glow
        property real dim: root.checked ? 0 : 1
        property color cBody: root.theme.accent
        // Taken toward the darkest, so the bands show whatever the accent: in Cosmos the
        // accent and peach are the same orange.
        property color cBand: Colors.mix(root.theme.peach, cShade, 0.3)
        property color cLight: root.theme.text
        property color cShade: root.theme.crust
        property color cRing: root.theme.subtextBright
        fragmentShader: Qt.resolvedUrl("qsb/Knob.qsb")
    }
}
