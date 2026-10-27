import QtQuick
import "common/Colors.js" as Colors
import "Sugar.js" as Sugar
import "common"

// Sugar's clock face: an entremet from above under a marbled mirror glaze, flecked with
// gold leaf and collared in icing lace; sugar pearls at the hours and gold dragées at
// the quarters, chocolate hands edged in gold under a rose of pulled sugar, and a gold
// dragée gliding round with the seconds.
Item {
    id: root

    // ── Speshell effects API v1: clock ──────────────────────
    property var theme: null
    property int hours: 0
    property int minutes: 0
    property int seconds: 0
    property bool running: true

    ClockTime {
        id: time
        hours: root.hours
        minutes: root.minutes
        seconds: root.seconds
        running: root.running
    }

    ShaderEffect {
        anchors.fill: parent
        property size area: Qt.size(width, height)
        property real hourTurn: time.hourTurn
        property real minuteTurn: time.minuteTurn
        property real secondTurn: time.secondTurn
        property real seconds: root.running ? 1 : 0
        property color cGlaze: Colors.mix(Sugar.frosting(root.theme), Sugar.chocolate(root.theme), 0.35)
        property color cGlazeDeep: Colors.mix(Sugar.frosting(root.theme), Sugar.ink(root.theme), 0.6)
        property color cGlazeLight: Sugar.frostingLight(root.theme)
        property color cSheen: Sugar.sparkle(root.theme)
        property color cLace: Sugar.cream(root.theme)
        property color cPearlShade: Colors.mix(Sugar.cream(root.theme), Sugar.metalShade(root.theme), 0.55)
        property color cGold: Sugar.gold(root.theme)
        property color cGoldShade: Colors.mix(Sugar.gold(root.theme), Sugar.chocolate(root.theme), 0.5)
        property color cChocolate: Sugar.chocolate(root.theme)
        property color cRose: Sugar.frosting(root.theme)
        property color cRoseLight: Sugar.frostingLight(root.theme)
        property color cRoseShade: Sugar.frostingShade(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/Clock.qsb")
    }
}
