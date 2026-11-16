import QtQuick
import "common"

// Earth's clock face: a carved stone dial, layered and cracked, with jade set at the
// hours, a pale stone hour hand and a jade minute hand, and a gold pebble rolling round
// a groove with the seconds.
Face {
    id: root

    property color cStone: root.theme.card
    property color cStoneLight: root.theme.surface2
    property color cRock: root.theme.overlay
    property color cLight: root.theme.subtextBright
    property color cShade: root.theme.crust
    property color cWarm: root.theme.peach
    property color cJade: root.theme.accent
    property color cGlint: root.theme.text
    property color cGold: root.theme.yellow
    fragmentShader: Qt.resolvedUrl("qsb/Clock.qsb")
}
