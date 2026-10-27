import QtQuick
import "Bolt.js" as Bolt
import "common"

// Relâmpago's clock face: a racing tachometer. Asphalt under a scale of minute ticks with
// a redline before twelve, needles for hands on a checkered cap, and a bolt of lightning
// that strikes from the cap to the second's tick, crackling.
Item {
    id: root

    // ── Speshell effects API v1: clock ──────────────────────
    property var theme: null
    property int hours: 0
    property int minutes: 0
    property int seconds: 0
    property bool running: true

    ClockTime {
        id: time
        hours: root.hours
        minutes: root.minutes
        seconds: root.seconds
        running: root.running
    }

    ShaderEffect {
        anchors.fill: parent
        property size area: Qt.size(width, height)
        property real hourTurn: time.hourTurn
        property real minuteTurn: time.minuteTurn
        property real secondTurn: time.secondTurn
        property real seconds: root.running ? 1 : 0
        property real secondIndex: root.seconds
        property real time: time.clock
        property color cAsphalt: root.theme ? root.theme.bg : "#19171a"
        property color cRubber: Bolt.rubber(root.theme)
        property color cBezel: root.theme ? root.theme.surface2 : "#463f44"
        property color cTick: root.theme ? root.theme.text : "#f6eee8"
        property color cDim: root.theme ? root.theme.overlay : "#6c6268"
        property color cPaint: Bolt.paint(root.theme)
        property color cCore: Bolt.core(root.theme)
        property color cGlow: Bolt.glow(root.theme)
        property color cEdge: Bolt.edge(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/Clock.qsb")
    }
}
