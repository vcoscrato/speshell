import QtQuick
import "common"

// Cosmos's button face: a lane of night in the accent, a planet's lit limb rising at
// one end and a scatter of stars. Hovered, the stars twinkle and a comet crosses.
ButtonFace {
    property color cBase: theme ? theme.accent : "#fe8019"
    property color cLight: theme ? theme.text : "#ebdbb2"
    property color cShade: theme ? theme.crust : "#1b1b1b"
    property color cRim: theme ? theme.yellow : "#fabd2f"
    fragmentShader: Qt.resolvedUrl("qsb/Button.qsb")
}
