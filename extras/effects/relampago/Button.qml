import QtQuick
import "common"
import "Bolt.js" as Bolt

// Relâmpago's button face: racing paint in the accent with speed stripes and a
// checkered flag at the tail. Hovered, the stripes race and a bolt crackles along the
// foot.
ButtonFace {
    property color cPaint: Bolt.paint(theme)
    property color cRubber: Bolt.rubber(theme)
    property color cFlag: theme ? theme.text : "#f6eee8"
    property color cCore: Bolt.core(theme)
    property color cGlow: Bolt.glow(theme)
    fragmentShader: Qt.resolvedUrl("qsb/Button.qsb")
}
