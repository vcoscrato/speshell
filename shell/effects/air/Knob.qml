import QtQuick
import "common/Colors.js" as Colors
import "common"

// Air's knob for Speshell's sliders and switches: a ball of wind whose spiral arms
// spin as it travels, with wisps circling it while held or hovered.
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

    // The wisps circle only while they show.
    Loader {
        id: breeze
        active: root.glow > 0 && root.checked
        sourceComponent: Component { EffectClock {} }
    }

    ShaderEffect {
        anchors.centerIn: parent
        width: root.size * 2
        height: root.size * 2
        property size area: Qt.size(width, height)
        property real size: root.size
        // Spinning twice as fast as it would roll.
        property real turn: root.travel / Math.max(1, root.size / 4)
        property real glow: root.glow
        property real dim: root.checked ? 0 : 1
        property real time: breeze.item ? breeze.item.clock : 0
        property color cBody: root.theme.bg
        property color cWind: root.theme.text
        property color cAccent: root.theme.accent
        property color cOutline: root.theme.crust
        fragmentShader: Qt.resolvedUrl("qsb/Knob.qsb")
    }
}
