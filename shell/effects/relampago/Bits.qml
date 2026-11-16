import QtQuick
import "common/Colors.js" as Colors
import "common"
import "Bolt.js" as Bolt

// Relâmpago's particles, drawn like cartoons: sparks, tire smoke, comic starbursts,
// lightning strikes and arcs, and glints, each a small shader drawn by its age. See
// Bits.frag.
Particles {
    id: root

    property var theme: Colors.fallback

    readonly property int spark: 0
    readonly property int smoke: 1
    readonly property int star: 2
    readonly property int strike: 3     // from the item's top; turn it with `angle`
    readonly property int arc: 4
    readonly property int glint: 5

    delegate: Component {
        ShaderEffect {
            property real age: 0
            property real seed: 0
            property real kind: 0
            property real size: width
            property color cCore: Bolt.core(root.theme)
            property color cGlow: Bolt.glow(root.theme)
            property color cEdge: Bolt.edge(root.theme)
            property color cPaint: Bolt.paint(root.theme)
            property color cRubber: Bolt.rubber(root.theme)
            property color cSmoke: Bolt.smoke(root.theme)
            property color cSmokeShade: Bolt.smokeShade(root.theme)
            fragmentShader: Qt.resolvedUrl("qsb/Bits.qsb")
        }
    }
}
