import QtQuick
import "common/Colors.js" as Colors
import "Natal.js" as Natal
import "common"

// Natal's clock face: an evergreen wreath from above round a night with a few
// snowflakes falling, holly and berries at the hours and a red bow at six, gilt hands,
// and a bead of light running round inside the wreath with the seconds.
Face {
    id: root

    property color cNight: Colors.mix(root.theme.crust, root.theme.blue, 0.06)
    property color cShadow: root.theme.crust
    property color cPineDeep: Natal.pineDeep(root.theme)
    property color cPine: Natal.pine(root.theme)
    property color cPineLight: Natal.pineLight(root.theme)
    property color cHolly: Natal.holly(root.theme)
    property color cHollyLight: Natal.hollyLight(root.theme)
    property color cBerry: Natal.berry(root.theme)
    property color cBerryDeep: Natal.berryDeep(root.theme)
    property color cBerryLight: Natal.berryLight(root.theme)
    property color cGold: Natal.gold(root.theme)
    property color cGoldDeep: Natal.goldDeep(root.theme)
    property color cGlint: root.theme.text
    property color cGlow: Natal.glow(root.theme)
    property color cSnow: Natal.snow(root.theme)
    fragmentShader: Qt.resolvedUrl("qsb/Clock.qsb")
}
