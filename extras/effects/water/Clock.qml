import QtQuick
import "Water.js" as Water
import "common"

// Water's clock face: a pool seen from above, caustics drifting over its floor, drops
// for the hours, glassy currents for hands around a whirlpool, and a drop that falls
// each second and ripples where it lands.
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
        property real sinceTick: time.sinceTick
        property real time: time.clock
        property color cDeep: Water.deep(root.theme)
        property color cMid: Water.mid(root.theme)
        property color cLight: Water.light(root.theme)
        property color cFoam: Water.foam(root.theme)
        property color cAbyss: root.theme ? root.theme.crust : "#081016"
        property color cRim: root.theme ? root.theme.surface2 : "#284354"
        property color cTeal: root.theme ? root.theme.teal : "#5cc6c0"
        fragmentShader: Qt.resolvedUrl("qsb/Clock.qsb")
    }
}
