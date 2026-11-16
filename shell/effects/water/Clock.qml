import QtQuick
import "Water.js" as Water
import "common"

// Water's clock face: a pool seen from above, caustics drifting over its floor, drops
// for the hours, glassy currents for hands around a whirlpool, and a drop that falls
// each second and ripples where it lands.
Face {
    id: root

    property color cDeep: Water.deep(root.theme)
    property color cMid: Water.mid(root.theme)
    property color cLight: Water.light(root.theme)
    property color cFoam: Water.foam(root.theme)
    property color cAbyss: root.theme.crust
    property color cRim: root.theme.surface2
    property color cTeal: root.theme.teal
    fragmentShader: Qt.resolvedUrl("qsb/Clock.qsb")
}
