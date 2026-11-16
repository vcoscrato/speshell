import QtQuick
import "common/Colors.js" as Colors

// Leaves and dust carried around a center by the wind. See Debris.frag.
// Each piece is a diamond of its own that Debris.vert fits to where it is, so a pixel
// pays only for the pieces over it; the item covers the ring they can reach.
ShaderEffect {
    readonly property real extent: r0 * 1.46 + 1.5 * turbulence + 1.6 * leafSize + 22
    x: center.x - extent
    y: center.y - extent
    width: 2 * extent
    height: 2 * extent
    // Three rows of vertices for each of up to 24 specks and 16 leaves (Debris.glsl).
    mesh: GridMesh {
        resolution: Qt.size(1, 3 * (24 + 16) - 1)
    }
    property real time: 0
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
    property var theme: Colors.fallback
    property color cLeaf: theme.accent
    property color cLeafBack: Colors.mix(theme.accent, theme.crust, 0.25)
    property color cOutline: Colors.mix(theme.crust, theme.accent, 0.3)
    property color cDust: theme.rosewater
    property color cGlint: theme.text
    vertexShader: Qt.resolvedUrl("qsb/Debris.vert.qsb")
    fragmentShader: Qt.resolvedUrl("qsb/Debris.qsb")
}
