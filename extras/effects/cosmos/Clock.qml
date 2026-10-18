import QtQuick
import "common"

// Cosmos's clock face: an orrery. The hour's planet circles close to the sun and the
// minute's ringed giant farther out, each held to it by a faint line; a comet runs the
// outer orbit with the seconds. Stars mark the hours over a nebula lane and star dust.
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
        property color cSpace: root.theme ? root.theme.mantle : "#1d2021"
        property color cDeep: root.theme ? root.theme.crust : "#1b1b1b"
        property color cRim: root.theme ? root.theme.surface2 : "#665c54"
        property color cText: root.theme ? root.theme.text : "#ebdbb2"
        property color cDim: root.theme ? root.theme.subtext : "#bdae93"
        property color cSun: root.theme ? root.theme.yellow : "#fabd2f"
        property color cSunEdge: root.theme ? root.theme.accent : "#fe8019"
        property color cHour: root.theme ? root.theme.error : "#fb4934"
        property color cHourBand: root.theme ? root.theme.peach : "#fe8019"
        property color cMinute: root.theme ? root.theme.sky : "#83a598"
        property color cMinuteBand: root.theme ? root.theme.teal : "#8ec07c"
        property color cNebula: root.theme ? root.theme.pink : "#d3869b"
        fragmentShader: Qt.resolvedUrl("qsb/Clock.qsb")
    }
}
