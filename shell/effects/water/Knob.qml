import QtQuick
import "common"

// Water's knob for Speshell's sliders and switches: a drop that stretches along
// its motion and wobbles back, ringed by a ripple while held or hovered.
Item {
    id: root

    // ── Speshell effects API v1: knob ───────────────────────
    property var theme: null
    property bool pressed: false
    property bool hovered: false
    property bool checked: true
    property real travel: 0

    readonly property real size: Math.min(width, height)
    // Lags the knob, overshooting a little, so the gap between them is its motion and
    // the wobble after it.
    property real trail: root.travel
    property real glow: root.pressed || root.hovered ? 1 : 0

    Behavior on trail { SpringAnimation { spring: 6; damping: 0.25 } }
    Behavior on glow { NumberAnimation { duration: 150 } }

    // The ripple swells only while it shows.
    Loader {
        id: swell
        active: root.glow > 0 && root.checked
        sourceComponent: Component { EffectClock {} }
    }

    ShaderEffect {
        anchors.centerIn: parent
        width: root.size * 2
        height: root.size * 2
        property size area: Qt.size(width, height)
        property real size: root.size
        property real stretch: Math.max(-1, Math.min(1, (root.travel - root.trail) / 14))
        property real glow: root.glow
        property real dim: root.checked ? 0 : 1
        property real time: swell.item ? swell.item.clock : 0
        property color cWater: root.theme ? root.theme.accent : "#4a97d8"
        property color cLight: root.theme ? root.theme.sky : "#7fd3f0"
        property color cFoam: root.theme ? root.theme.text : "#e3eef4"
        property color cDeep: root.theme ? root.theme.crust : "#081016"
        fragmentShader: Qt.resolvedUrl("qsb/Knob.qsb")
    }
}
