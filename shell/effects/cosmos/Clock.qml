import QtQuick
import "common"

// Cosmos's clock face: an orrery. The hour's planet circles close to the sun and the
// minute's ringed giant farther out, each held to it by a faint line; a comet runs the
// outer orbit with the seconds. Stars mark the hours over a nebula lane and star dust.
Face {
    id: root

    property color cSpace: root.theme.mantle
    property color cDeep: root.theme.crust
    property color cRim: root.theme.surface2
    property color cText: root.theme.text
    property color cDim: root.theme.subtext
    property color cSun: root.theme.yellow
    property color cSunEdge: root.theme.accent
    property color cHour: root.theme.error
    property color cHourBand: root.theme.peach
    property color cMinute: root.theme.sky
    property color cMinuteBand: root.theme.teal
    property color cNebula: root.theme.pink
    fragmentShader: Qt.resolvedUrl("qsb/Clock.qsb")
}
