import QtQuick
import "common/Colors.js" as Colors
import "common"
import "Natal.js" as Natal

// Natal's particles: glints, snowflakes that grow and break, tiny flakes, and a warm
// bloom of fairy lights, each a small shader drawn by its age. See Bits.frag.
Particles {
    id: root

    property var theme: Colors.fallback

    readonly property int glint: 0
    readonly property int flake: 1      // turned by its `turn`
    readonly property int mote: 2
    readonly property int bloom: 3

    delegate: Component {
        ShaderEffect {
            property real age: 0
            property real seed: 0
            property real kind: 0
            property real turn: 0
            property real size: width
            property color cSnow: Natal.snow(root.theme)
            property color cIce: Natal.ice(root.theme)
            property color cShade: Natal.pineDeep(root.theme)
            property color cSheen: root.theme.text
            property color cGlow: Natal.glow(root.theme)
            property color cGold: Natal.gold(root.theme)
            fragmentShader: Qt.resolvedUrl("qsb/Bits.qsb")
        }
    }
}
