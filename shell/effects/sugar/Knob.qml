import QtQuick
import "Sugar.js" as Sugar

// Sugar's knob for Speshell's sliders and switches: frosting piped along the track
// back to its start, ending at the knob in a kiss. As the pointer nears, a piping bag
// comes down onto the kiss, and going back, a spatula scrapes the frosting off.
// Switched off, the track is bare and the kiss is plain meringue.
Item {
    id: root

    // ── Speshell effects API v1: knob ───────────────────────
    property var theme: null
    property bool pressed: false
    property bool hovered: false
    property bool checked: true
    property real travel: 0
    property point pointer: Qt.point(0, 0)

    readonly property real size: Math.min(width, height)
    // The pointer along the track, so it stays put as the knob moves under the wheel.
    property real pointerX: 0
    onPointerChanged: pointerX = pointer.x - width / 2 + travel

    // How near the pointer is: a tool comes down as it nears, and stays while held or
    // while the wheel moves the knob out from under a still pointer.
    property real near: root.pressed || root.hovered && root.moving ? 1 : !root.hovered ? 0
        : 1 - Math.max(0, Math.min(1, (Math.abs(root.pointerX - root.travel) - root.size) / (root.size * 5)))
    property bool moving: false
    // Whether the knob last went back, which brings the spatula instead of the bag.
    property bool back: false
    property real scrape: root.back ? 1 : 0
    property real squeeze: root.pressed ? 1 : 0
    // Lags the knob, so the gap between them is how fast it moves.
    property real trail: root.travel
    property real fill: root.checked ? 1 : 0

    // The furthest the knob has gone in its current direction: the tools swap only once
    // it has come well back from there, so a hand trembling on the knob never swaps them.
    property real turn: root.travel
    onTravelChanged: {
        if (root.back ? root.travel < root.turn : root.travel > root.turn)
            root.turn = root.travel;
        else if (Math.abs(root.travel - root.turn) > Math.max(12, root.size * 0.7)) {
            root.back = !root.back;
            root.turn = root.travel;
        }
        if (root.hovered) {
            root.moving = true;
            settle.restart();
        }
    }

    Timer {
        id: settle
        interval: 700
        onTriggered: root.moving = false
    }
    onNearChanged: if (root.near === 0) root.back = false

    Behavior on near { SmoothedAnimation { velocity: 5 } }
    Behavior on scrape { NumberAnimation { duration: 140 } }
    Behavior on squeeze { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
    Behavior on trail { SpringAnimation { spring: 5; damping: 0.7 } }
    Behavior on fill { NumberAnimation { duration: 180 } }

    // Reaches back along the track to its start for the piped frosting, and up over
    // the knob for the bag and the spatula.
    ShaderEffect {
        readonly property real reach: root.travel + root.size / 2
        readonly property real margin: root.size * 0.3
        x: root.width / 2 - reach - margin
        y: root.height / 2 - root.size * 3.2
        width: reach + margin + root.size * 2.9
        height: root.size * 4.0
        property size area: Qt.size(width, height)
        property point center: Qt.point(reach + margin, root.size * 3.2)
        property real size: root.size
        property real back: reach
        property real lag: Math.max(-1, Math.min(1, (root.travel - root.trail) / 20))
        property real squeeze: root.squeeze
        property real fill: root.fill
        property real near: root.near
        property real scrape: root.scrape
        property color cFrost: Sugar.frosting(root.theme)
        property color cFrostLight: Sugar.frostingLight(root.theme)
        property color cFrostShade: Sugar.frostingShade(root.theme)
        property color cFilm: Sugar.sparkle(root.theme)
        property color cMetal: Sugar.metal(root.theme)
        property color cMetalShade: Sugar.metalShade(root.theme)
        property color cMeringue: Sugar.cream(root.theme)
        property color cHandle: Sugar.wood(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/Knob.qsb")
    }
}
