import QtQuick
import "common"

// Earth's clock face: a carved stone dial, layered and cracked, with jade set at the
// hours, a pale stone hour hand and a jade minute hand, and a gold pebble rolling round
// a groove with the seconds.
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
        property color cStone: root.theme ? root.theme.card : "#22281b"
        property color cStoneLight: root.theme ? root.theme.surface2 : "#3f4832"
        property color cRock: root.theme ? root.theme.overlay : "#677052"
        property color cLight: root.theme ? root.theme.subtextBright : "#c6c6ad"
        property color cShade: root.theme ? root.theme.crust : "#0d0f0a"
        property color cWarm: root.theme ? root.theme.peach : "#d99a5a"
        property color cJade: root.theme ? root.theme.accent : "#5fa57a"
        property color cGlint: root.theme ? root.theme.text : "#e9e6d3"
        property color cGold: root.theme ? root.theme.yellow : "#d9b44a"
        fragmentShader: Qt.resolvedUrl("qsb/Clock.qsb")
    }
}
