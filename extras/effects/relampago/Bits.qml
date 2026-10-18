import QtQuick
import "common"
import "Bolt.js" as Bolt

// Relâmpago's particles: sparks, tire smoke, and lightning in bursts, strikes, and
// arcs, each a small shader drawn by its age. See Bits.frag.
Particles {
    id: root

    property var theme: null

    readonly property int spark: 0
    readonly property int smoke: 1
    readonly property int burst: 2
    readonly property int strike: 3     // from the item's top; turn it with `angle`
    readonly property int arc: 4

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
            property color cCore: Bolt.core(root.theme)
            property color cGlow: Bolt.glow(root.theme)
            property color cEdge: Bolt.edge(root.theme)
            property color cRubber: Bolt.rubber(root.theme)
            property color cSmoke: Bolt.smoke(root.theme)
            property color cSmokeShade: Bolt.smokeShade(root.theme)
            fragmentShader: Qt.resolvedUrl("qsb/Bits.qsb")
        }
    }
}
