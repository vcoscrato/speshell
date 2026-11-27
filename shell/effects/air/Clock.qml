import QtQuick
import "common"

// Air's clock face: a dusky sky with cloud banks drifting and wind circling its middle,
// a compass rose under a leaf and a feather for hands, and a leaf riding the wind round
// the rim with the seconds.
Face {
    id: root

    property color cSky: root.theme.mantle
    property color cDeep: root.theme.crust
    property color cCloud: root.theme.card
    property color cCloudLight: root.theme.surface2
    property color cRim: root.theme.overlay
    property color cWind: root.theme.text
    property color cDim: root.theme.subtext
    property color cAccent: root.theme.accent
    property color cLeaf: root.theme.peach
    fragmentShader: Qt.resolvedUrl("qsb/Clock.qsb")
}
