import QtQuick
import "common"

// Air's clock face: a dusky sky with cloud banks drifting and wind circling its middle,
// a compass rose under a leaf and a feather for hands, and a leaf riding the wind round
// the rim with the seconds.
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
        property color cSky: root.theme ? root.theme.mantle : "#1a150f"
        property color cDeep: root.theme ? root.theme.crust : "#130f0b"
        property color cCloud: root.theme ? root.theme.card : "#2f271d"
        property color cCloudLight: root.theme ? root.theme.surface2 : "#514331"
        property color cRim: root.theme ? root.theme.overlay : "#7a6650"
        property color cWind: root.theme ? root.theme.text : "#f4ead8"
        property color cDim: root.theme ? root.theme.subtext : "#b8a68c"
        property color cAccent: root.theme ? root.theme.accent : "#f39a3a"
        property color cLeaf: root.theme ? root.theme.peach : "#f0a03c"
        property color cSkyBlue: root.theme ? root.theme.sky : "#7cc0ea"
        fragmentShader: Qt.resolvedUrl("qsb/Clock.qsb")
    }
}
