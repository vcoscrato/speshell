import QtQuick
import "common"
import "common/Colors.js" as Colors
import "Christmas.js" as Christmas

// Christmas launcher transition: the launcher opens at once through a skin of frost that
// thaws away from many points, leaving a rime of frost feathers outside its corners
// and edges. While it is open a string of fairy lights is hung round it, a run along
// its top and then swag by swag, outside its edge; the bulbs light up in turn and
// twinkle, snow falls round it at three depths, and a drift settles on its top edge.
// Closing, it is wrapped as a present, two flaps of paper folding in from its sides,
// a gold ribbon crossing it and a bow, and lifts away as the lights drop off and the
// drift puffs away.
LauncherStage {
    id: root

    enterTime: 0.4
    exitTime: 0.6
    tailTime: 0.05

    // Seconds open, which paces the decorating.
    property real open: 0
    readonly property real hangStart: 0.45
    readonly property real hangTime: 3.0
    // The string: runs along the top, swags round the rest, and bulbs on it, kept as
    // the panel resizes (see held()).
    property int topRuns: 0
    property int swags: 0
    property int bulbs: 0
    // Which way the package tilts as it lifts.
    property real tilt: 1

    function span(x, a, b) { return Math.max(0, Math.min(1, (x - a) / (b - a))); }

    // A count of pieces about target px long over length px, kept while each stays
    // within 0.7..1.45 times the target, so the lights don't rearrange as it resizes.
    function held(n, length, target, least) {
        const each = length / Math.max(1, n);
        if (n >= least && each > target * 0.7 && each < target * 1.45)
            return n;
        return Math.max(least, Math.round(length / target));
    }

    function relayout() {
        const w = root.panelRect.width, h = root.panelRect.height;
        const r = Math.min(root.panelRadius, w / 2, h / 2);
        const top = w - 2 * r + Math.PI * r, rest = w + 2 * h - 6 * r + Math.PI * r;
        root.topRuns = root.held(root.topRuns, top, 170, 1);
        root.swags = root.held(root.swags, rest, 115, 2);
        root.bulbs = Math.min(128, root.held(root.bulbs, top + rest, 27, 8));
    }

    onPanelRectChanged: root.relayout()
    onPanelRadiusChanged: root.relayout()
    Component.onCompleted: root.relayout()

    onActiveChanged: {
        if (!root.active && root.leave === 0)
            root.tilt = Math.random() < 0.5 ? -1 : 1;
    }

    onAdvanced: dt => {
        if (root.active && root.leave === 0)
            root.open += dt;
    }

    // The package lifting away, accelerating, after a little dip as the bow pops.
    readonly property real up: span(leave, 0.5, 1)
    readonly property real liftY: -360 * up * up + 5 * Math.sin(Math.PI * span(leave, 0.42, 0.56))

    // ── The snow, the lights, and the drift ──
    ShaderEffect {
        z: 1
        x: root.panelRect.x - 180
        y: root.panelRect.y - 200
        width: root.panelRect.width + 360
        height: root.panelRect.height + 380
        visible: root.panel !== null && root.open > 0.3 && root.leave < 1
        // Rows of vertices for every piece (LauncherTransition.decor.glsl).
        mesh: GridMesh {
            resolution: Qt.size(1, 3 * (64 + 40) + 560 + 3 * (128 + 1 + 128 + 28 + 22) - 1)
        }
        property point origin: Qt.point(x, y)
        property rect rect: root.panelRect
        property real radius: root.panelRadius
        property real time: root.clock.simTime
        property real open: root.open
        property real leave: root.leave
        property real exitTime: root.exitTime
        property real topRuns: root.topRuns
        property real swags: root.swags
        property real bulbs: root.bulbs
        property real hangStart: root.hangStart
        property real hangGap: root.hangTime / Math.max(1, root.topRuns + root.swags)
        property color cWire: Colors.mix(Christmas.pineDeep(root.theme), root.theme.crust, 0.3)
        property color cWireLit: Christmas.pine(root.theme)
        property color cSocket: Christmas.pineDeep(root.theme)
        property color cSocketLit: Christmas.pineLight(root.theme)
        readonly property var palette: Christmas.bulbs(root.theme)
        property color cBulb0: palette[0]
        property color cBulb1: palette[1]
        property color cBulb2: palette[2]
        property color cBulb3: palette[3]
        property color cBulb4: palette[4]
        property color cGlint: root.theme.text
        property color cDark: root.theme.crust
        property color cSnow: Christmas.snow(root.theme)
        property color cSnowShade: Christmas.snowShade(root.theme)
        property color cSnowLit: root.theme.text
        vertexShader: Qt.resolvedUrl("qsb/LauncherTransition.decor.vert.qsb")
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.decor.qsb")
    }

    // ── The panel through the frost, its rime, and the present ──
    // Above the lights only while it is wrapped and lifts away.
    ShaderEffect {
        readonly property real pad: root.leave > 0 ? root.panelRect.width * 0.5 + 10 : 24
        readonly property real padTop: root.leave > 0 ? root.panelRect.height * 0.3 + 40 - root.liftY : 24
        z: root.leave > 0 ? 2 : 0
        x: root.panelRect.x - pad
        y: root.panelRect.y - padTop
        width: root.panelRect.width + 2 * pad
        height: root.panelRect.height + padTop + (root.leave > 0 ? root.panelRect.height * 0.3 + 20 : 24)
        visible: root.panel !== null && (root.capturing || rime > 0)
        property var source: root.panelTexture
        property point origin: Qt.point(x, y)
        property size resolution: Qt.size(width, height)
        property rect rect: root.panelRect
        property real radius: root.panelRadius
        property real capture: root.capturing ? 1 : 0
        property real thaw: root.enter
        property real rime: root.span(root.open, 0.1, 0.6) * (1 - root.span(root.leave, 0, 0.22))
        property real leave: root.leave
        property vector4d lift: Qt.vector4d(0, root.liftY, 1 - 0.25 * Math.pow(root.up, 1.5), root.tilt * 0.13 * Math.pow(root.up, 1.3))
        property real fade: 1 - root.span(root.leave, 0.82, 1)
        property color cFrost: Colors.mix(Christmas.ice(root.theme), root.theme.bg, 0.3)
        property color cIce: Christmas.ice(root.theme)
        property color cFrostLit: root.theme.text
        property color cPaper: Christmas.berry(root.theme)
        property color cPaperDeep: Christmas.berryDeep(root.theme)
        property color cPaperLit: Colors.mix(Christmas.berry(root.theme), root.theme.rosewater, 0.22)
        property color cPaperBack: Colors.mix(root.theme.text, root.theme.rosewater, 0.4)
        property color cPaperBackShade: Colors.mix(cPaperBack, root.theme.overlay, 0.45)
        property color cGold: Christmas.gold(root.theme)
        property color cGoldDeep: Christmas.goldDeep(root.theme)
        property color cGoldLit: Colors.mix(Christmas.gold(root.theme), root.theme.text, 0.5)
        property color cShadow: root.theme.crust
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.qsb")
    }
}
