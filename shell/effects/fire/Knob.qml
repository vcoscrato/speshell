import QtQuick
import "Flame.js" as Flame
import "common"

// Fire's knob for Speshell's sliders and switches: an ember whose cracks roll as
// it moves, burning hotter while held or hovered, when a flame rises off it.
Item {
    id: root

    // ── Speshell effects API v1: knob ───────────────────────
    property var theme: null
    property bool pressed: false
    property bool hovered: false
    property bool checked: true
    property real travel: 0

    readonly property real size: Math.min(width, height)
    // Lags the knob, so the gap between them is its motion.
    property real trail: root.travel
    property real glow: root.pressed || root.hovered ? 1 : 0

    Behavior on trail { NumberAnimation { duration: 140 } }
    Behavior on glow { NumberAnimation { duration: 150 } }

    // The flame flickers only while it shows.
    Loader {
        id: flicker
        active: root.glow > 0 && root.checked
        sourceComponent: Component { EffectClock {} }
    }

    ShaderEffect {
        anchors.centerIn: parent
        width: root.size * 2
        height: root.size * 3.4
        anchors.verticalCenterOffset: -root.size * 0.7
        property size area: Qt.size(width, height)
        property point center: Qt.point(0, root.size * 0.7)
        property real size: root.size
        property real turn: root.travel / Math.max(1, root.size / 2)
        property real glow: root.glow
        property real dim: root.checked ? 0 : 1
        property real lean: Math.max(-1, Math.min(1, (root.trail - root.travel) / 12))
        property real time: flicker.item ? flicker.item.clock : 0
        property color cCore: Flame.core(root.theme)
        property color cMid: Flame.mid(root.theme)
        property color cOuter: Flame.outer(root.theme)
        property color cEdge: Flame.edge(root.theme)
        property color cCoal: root.theme ? root.theme.crust : "#11080a"
        property color cAsh: root.theme ? root.theme.subtext : "#b99a89"
        fragmentShader: Qt.resolvedUrl("qsb/Knob.qsb")
    }
}
