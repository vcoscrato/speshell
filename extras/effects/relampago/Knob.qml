import QtQuick
import "common"
import "Bolt.js" as Bolt
import "common/Colors.js" as Colors

// Relâmpago's knob for Speshell's sliders and switches: a racing wheel that
// rolls as it travels, carrying a bolt decal along the filled track behind it, with
// electricity crackling along the track and around the wheel while held or hovered.
Item {
    id: root

    // ── Speshell effects API v1: knob ───────────────────────
    property var theme: null
    property bool pressed: false
    property bool hovered: false
    property bool checked: true
    property real travel: 0

    readonly property real size: Math.min(width, height)
    property real glow: root.pressed || root.hovered ? 1 : 0

    Behavior on glow { NumberAnimation { duration: 150 } }

    // The crackle runs only while it shows.
    Loader {
        id: crackle
        active: root.glow > 0 && root.checked
        sourceComponent: Component { EffectClock {} }
    }

    // Reaches back along the track to its start, for the charge in the fill.
    ShaderEffect {
        readonly property real reach: root.checked ? root.travel + root.size / 2 : 0
        x: root.width / 2 - reach - 4
        y: root.height / 2 - root.size * 1.2
        width: reach + 4 + root.size * 1.6
        height: root.size * 2.4
        property size area: Qt.size(width, height)
        property point center: Qt.point(reach + 4, root.size * 1.2)
        property real size: root.size
        property real back: reach
        // Rolling: one turn per circumference travelled.
        property real turn: root.travel / Math.max(1, root.size / 2)
        property real glow: root.glow
        property real dim: root.checked ? 0 : 1
        property real time: crackle.item ? crackle.item.clock : 0
        property color cTire: Bolt.rubber(root.theme)
        property color cWall: root.theme ? Colors.mix(root.theme.crust, root.theme.text, 0.22) : "#3a3638"
        property color cGold: Bolt.glow(root.theme)
        property color cPaint: Bolt.paint(root.theme)
        property color cCore: Bolt.core(root.theme)
        property color cEdge: Bolt.edge(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/Knob.qsb")
    }
}
