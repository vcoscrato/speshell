import QtQuick
import "Flame.js" as Flame
import "common"

// Fire's clock face: a disc of charcoal cracked with embers inside a ring of low flames,
// forged blades for hands, their edges hot, and an ember running round with the seconds.
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
        property real time: time.clock
        property color cCoal: root.theme ? root.theme.crust : "#11080a"
        property color cAsh: root.theme ? root.theme.mantle : "#190d0f"
        property color cIron: root.theme ? root.theme.cardHover : "#47221f"
        property color cRim: root.theme ? root.theme.surface2 : "#602d2b"
        property color cText: root.theme ? root.theme.text : "#f3e3d3"
        property color cCore: Flame.core(root.theme)
        property color cMid: Flame.mid(root.theme)
        property color cOuter: Flame.outer(root.theme)
        property color cEdge: Flame.edge(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/Clock.qsb")
    }
}
