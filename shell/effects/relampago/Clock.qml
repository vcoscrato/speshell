import QtQuick
import "Bolt.js" as Bolt
import "common"

// Relâmpago's clock face: a racing tachometer. Asphalt under a scale of minute ticks with
// a redline before twelve, needles for hands on a checkered cap, and a bolt of lightning
// that strikes from the cap to the second's tick, crackling.
Face {
    id: root

    property real secondIndex: root.seconds
    property color cAsphalt: root.theme.bg
    property color cRubber: Bolt.rubber(root.theme)
    property color cBezel: root.theme.surface2
    property color cTick: root.theme.text
    property color cDim: root.theme.overlay
    property color cPaint: Bolt.paint(root.theme)
    property color cCore: Bolt.core(root.theme)
    property color cGlow: Bolt.glow(root.theme)
    property color cEdge: Bolt.edge(root.theme)
    fragmentShader: Qt.resolvedUrl("qsb/Clock.qsb")
}
