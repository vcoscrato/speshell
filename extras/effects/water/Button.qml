import QtQuick
import "common"

// Water's button face: a pool in the accent with caustics on its floor and a bright
// meniscus at the top. Hovered, the caustics drift and rings spread from the pointer.
ButtonFace {
    property color cWater: theme ? theme.accent : "#4a97d8"
    property color cLight: theme ? theme.sky : "#7fd3f0"
    property color cFoam: theme ? theme.text : "#e3eef4"
    property color cDeep: theme ? theme.crust : "#081016"
    fragmentShader: Qt.resolvedUrl("qsb/Button.qsb")
}
