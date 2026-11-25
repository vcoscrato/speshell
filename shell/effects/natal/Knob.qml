import QtQuick
import "common"
import "common/Colors.js" as Colors
import "Natal.js" as Natal

// Natal's knob for Speshell's sliders and switches: a glass bauble with a metal cap
// and a gilt band, rolling as it travels. On a slider it trails a string of fairy
// lights on a dark wire along the filled track, back to the track's start; on a
// switch it draws the whole switch, a short string of bulbs dark when off and lit when
// on, the bauble rolling along it. Held, it warms and glows; hovered, it sways a little.
Item {
    id: root

    // ── Speshell effects API v1: knob ───────────────────────
    property var theme: Colors.fallback
    property bool pressed: false
    property bool hovered: false
    property bool checked: true
    property real travel: 0
    property rect switchArea: Qt.rect(0, 0, 0, 0)

    readonly property bool isSwitch: root.switchArea.width > 0
    readonly property real size: Math.min(width, height)
    // The knob's size at rest, which sets the lights' spacing and the rolling, so
    // neither jumps as the knob grows under the hand.
    property real unit: 0
    onSizeChanged: if (root.size > 4 && (root.unit === 0 || root.size < root.unit)) root.unit = root.size

    property real warm: root.pressed ? 1 : 0
    property real fill: root.checked ? 1 : 0
    property real near: root.hovered ? 1 : 0
    Behavior on warm { NumberAnimation { duration: 220 } }
    Behavior on fill { NumberAnimation { duration: 200 } }
    Behavior on near { NumberAnimation { duration: 300 } }

    // Switched on, the bulbs come on one by one, flickering.
    property real kindle: 1
    onCheckedChanged: {
        kindling.stop();
        root.kindle = 0;
        if (root.checked)
            kindling.start();
    }
    NumberAnimation { id: kindling; target: root; property: "kindle"; from: 0; to: 1; duration: 420 }

    // Hovered, it swings from a nudge and keeps a slight sway, on a clock that runs
    // only then.
    Loader {
        id: swaying
        active: root.near > 0
        sourceComponent: Component { EffectClock {} }
    }
    readonly property real sway: {
        const t = swaying.item ? swaying.item.clock : 0;
        return root.near * (0.17 * Math.exp(-2.6 * t) * Math.sin(9 * t) + 0.045 * Math.sin(2.4 * t));
    }

    ShaderEffect {
        // On a slider, back along the track to its start and round the bauble; on a
        // switch, the whole switch and a little past it for the glow.
        readonly property real reach: root.isSwitch ? 0 : root.travel + root.size / 2
        readonly property real margin: root.size * (root.isSwitch ? 0.35 : 0.6)
        x: root.isSwitch ? root.switchArea.x - margin : root.width / 2 - reach - margin
        y: root.isSwitch ? root.switchArea.y - margin : root.height / 2 - root.size * 1.1
        width: root.isSwitch ? root.switchArea.width + 2 * margin : reach + margin + root.size * 1.1
        height: root.isSwitch ? root.switchArea.height + 2 * margin : root.size * 2.2
        property size area: Qt.size(width, height)
        property point center: Qt.point(root.width / 2 - x, root.height / 2 - y)
        property rect body: root.isSwitch ? Qt.rect(root.switchArea.x - x, root.switchArea.y - y, root.switchArea.width, root.switchArea.height) : Qt.rect(0, 0, 0, 0)
        property real size: root.size
        property real unit: Math.max(1, root.unit)
        property real back: reach
        // Rolling, clockwise as it moves right; a switch's is upright halfway along.
        property real turn: (root.travel - (root.isSwitch ? (root.switchArea.width - root.size) / 2 : 0)) / Math.max(1, root.unit * 0.41) + root.sway
        property real warm: root.warm
        property real lit: root.isSwitch ? root.fill : 1
        property real kindle: root.isSwitch ? root.kindle : 1
        // A slider's bauble is cranberry glass with a gilt band; a switch's is gilt
        // when on, with a cranberry band, and dull cranberry when off.
        readonly property real gilt: root.isSwitch ? root.fill : 0
        readonly property color ball: Colors.mix(Colors.mix(Natal.berry(root.theme), root.theme.crust, 0.3), Natal.gold(root.theme), gilt)
        readonly property color stripe: Colors.mix(Natal.goldDeep(root.theme), Natal.berry(root.theme), gilt)
        property color cBall: root.isSwitch ? ball : Natal.berry(root.theme)
        property color cBallLight: Colors.mix(cBall, root.theme.text, 0.3)
        property color cBallShade: Colors.mix(cBall, root.theme.crust, 0.3)
        property color cBallDeep: Colors.mix(cBall, root.theme.crust, 0.58)
        property color cBand: root.isSwitch ? stripe : Natal.gold(root.theme)
        property color cBandShade: Colors.mix(cBand, root.theme.crust, 0.35)
        property color cCap: Natal.goldDeep(root.theme)
        property color cCapLight: Colors.mix(Natal.gold(root.theme), root.theme.text, 0.25)
        property color cSheen: root.theme.text
        property color cGlow: Natal.glow(root.theme)
        property color cNight: Colors.mix(root.theme.crust, Natal.pineDeep(root.theme), 0.3)
        property color cRim: Colors.mix(root.theme.crust, root.theme.overlay, 0.4)
        property color cWire: Natal.pine(root.theme)
        readonly property var bulbs: Natal.bulbs(root.theme)
        property color cBulb0: bulbs[0]
        property color cBulb1: bulbs[1]
        property color cBulb2: bulbs[2]
        property color cBulb3: bulbs[3]
        property color cBulb4: bulbs[4]
        fragmentShader: Qt.resolvedUrl("qsb/Knob.qsb")
    }
}
