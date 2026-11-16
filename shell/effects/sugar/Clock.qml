import QtQuick
import "Sugar.js" as Sugar
import "common"

// Sugar's clock face: a raspberry tart from above, its fluted shell dusted with
// powdered sugar, glazed vanilla cream, raspberries at the hours, lancet hands of dark
// chocolate, and a thread of coulis for the seconds.
Face {
    id: root

    property color cCrust: Sugar.choux(root.theme)
    property color cCrustDeep: Sugar.chouxDeep(root.theme)
    property color cCrustLight: Sugar.sponge(root.theme)
    property color cCream: Sugar.cream(root.theme)
    property color cCreamShade: Sugar.creamShade(root.theme)
    property color cSheen: Sugar.sparkle(root.theme)
    property color cChocolate: Sugar.chocolate(root.theme)
    property color cChocolateDark: Sugar.chocolateDark(root.theme)
    property color cBerry: Sugar.berry(root.theme)
    property color cBerryDeep: Sugar.berryDeep(root.theme)
    property color cBerryLight: Sugar.berryLight(root.theme)
    fragmentShader: Qt.resolvedUrl("qsb/Clock.qsb")
}
