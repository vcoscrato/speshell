import QtQuick
import "common/Colors.js" as Colors
import "Christmas.js" as Christmas
import "common"

// Christmas's clock face: an evergreen wreath from above round a night with a few
// snowflakes falling, holly and berries at the hours and a red bow at six, gilt hands,
// and a bead of light running round inside the wreath with the seconds.
Face {
    id: root

    property color cNight: Colors.mix(root.theme.crust, root.theme.blue, 0.06)
    property color cShadow: root.theme.crust
    property color cPineDeep: Christmas.pineDeep(root.theme)
    property color cPine: Christmas.pine(root.theme)
    property color cPineLight: Christmas.pineLight(root.theme)
    property color cHolly: Christmas.holly(root.theme)
    property color cHollyLight: Christmas.hollyLight(root.theme)
    property color cBerry: Christmas.berry(root.theme)
    property color cBerryDeep: Christmas.berryDeep(root.theme)
    property color cBerryLight: Christmas.berryLight(root.theme)
    property color cGold: Christmas.gold(root.theme)
    property color cGoldDeep: Christmas.goldDeep(root.theme)
    property color cGlint: root.theme.text
    property color cGlow: Christmas.glow(root.theme)
    property color cSnow: Christmas.snow(root.theme)
    fragmentShader: Qt.resolvedUrl("qsb/Clock.qsb")
}
