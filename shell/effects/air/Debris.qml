import QtQuick
import "common/Colors.js" as Colors

// Leaves and dust carried around a center by the wind. See Debris.frag.
// Covers only the ring the debris can reach, centered on `center`.
ShaderEffect {
    readonly property real extent: r0 * 1.46 + 1.5 * turbulence + 1.6 * leafSize + 22
    x: center.x - extent
    y: center.y - extent
    width: 2 * extent
    height: 2 * extent
    property real time: 0
    property size resolution: Qt.size(width, height)
    property point origin: Qt.point(x, y)
    property point center
    property real leaves: 8
    property real dust: 14
    property real r0: 300
    property real spin: 1
    property real head: 0
    property real leafSize: 11
    property real turbulence: 12
    property rect mask
    property real maskRadius: 10
    property var theme: null
    property color cLeaf: theme ? theme.accent : "#f0a03c"
    property color cLeafBack: theme ? Colors.mix(theme.accent, theme.crust, 0.25) : "#c9711f"
    property color cOutline: theme ? Colors.mix(theme.crust, theme.accent, 0.3) : "#5a3417"
    property color cDust: theme ? theme.rosewater : "#e9f2fa"
    property color cGlint: theme ? theme.text : "#f4ead8"
    fragmentShader: Qt.resolvedUrl("qsb/Debris.qsb")
}
