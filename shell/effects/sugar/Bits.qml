import QtQuick
import "common"
import "Sugar.js" as Sugar

// Sugar's particles: sugar sparkles, powdered sugar sifted down, puffs of it, and cake
// crumbs, each a small shader drawn by its age. See Bits.frag.
Particles {
    id: root

    property var theme: null

    readonly property int sparkle: 0
    readonly property int sift: 1        // falls from the item's top over its height
    readonly property int puff: 2
    readonly property int crumb: 3

    function rnd(a, b) {
        return a + Math.random() * (b - a);
    }

    // Starts a particle of `kind` (see spawn() in common/Particles.qml for `p`).
    function emit(kind, p) {
        p.props = { kind: kind, seed: Math.random() };
        root.spawn(p);
    }

    delegate: Component {
        ShaderEffect {
            property real age: 0
            property real seed: 0
            property real kind: 0
            property real size: width
            property color cInk: Sugar.ink(root.theme)
            property color cFrost: Sugar.frosting(root.theme)
            property color cFrostLight: Sugar.frostingLight(root.theme)
            property color cFrostShade: Sugar.frostingShade(root.theme)
            property color cSparkle: Sugar.sparkle(root.theme)
            property color cCream: Sugar.cream(root.theme)
            property color cSponge: Sugar.sponge(root.theme)
            fragmentShader: Qt.resolvedUrl("qsb/Bits.qsb")
        }
    }
}
