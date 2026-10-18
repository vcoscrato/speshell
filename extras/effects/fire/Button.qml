import QtQuick
import "common"
import "Flame.js" as Flame

// Fire's button face: a bed of embers in the accent with low flames along its foot.
// Hovered, the flames rise and flicker and embers drift up.
ButtonFace {
    property color cBase: theme ? theme.accent : "#e8b04a"
    property color cMid: Flame.mid(theme)
    property color cOuter: Flame.outer(theme)
    property color cCore: Flame.core(theme)
    property color cShade: theme ? theme.crust : "#11080a"
    fragmentShader: Qt.resolvedUrl("qsb/Button.qsb")
}
