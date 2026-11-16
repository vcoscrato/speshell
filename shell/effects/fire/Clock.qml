import QtQuick
import "Flame.js" as Flame
import "common"

// Fire's clock face: a disc of charcoal cracked with embers inside a ring of low flames,
// forged blades for hands, their edges hot, and an ember running round with the seconds.
Face {
    id: root

    property color cCoal: root.theme.crust
    property color cAsh: root.theme.mantle
    property color cIron: root.theme.cardHover
    property color cRim: root.theme.surface2
    property color cText: root.theme.text
    property color cCore: Flame.core(root.theme)
    property color cMid: Flame.mid(root.theme)
    property color cOuter: Flame.outer(root.theme)
    property color cEdge: Flame.edge(root.theme)
    fragmentShader: Qt.resolvedUrl("qsb/Clock.qsb")
}
