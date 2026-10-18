import QtQuick
import "common"

// Air's button face: the accent under a lighter sky, crossed by dashes of wind.
// Hovered, the wind blows through it and a leaf rides along.
ButtonFace {
    property color cBase: theme ? theme.accent : "#f39a3a"
    property color cWind: theme ? theme.text : "#f4ead8"
    property color cShade: theme ? theme.crust : "#130f0b"
    property color cLeaf: theme ? theme.success : "#a3be8c"
    fragmentShader: Qt.resolvedUrl("qsb/Button.qsb")
}
