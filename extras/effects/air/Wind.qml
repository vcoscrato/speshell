import QtQuick
import "common/Colors.js" as Colors

// Wind streaks along the streamlines of a breeze, vortex, and source. See
// Wind.frag.
ShaderEffect {
    property real time: 0
    property size resolution: Qt.size(width, height)
    property point origin: Qt.point(x, y)
    property point center
    property size axes: Qt.size(300, 200)
    property real wind: 0
    property real windAngle: 0
    property real obstacle: 0
    property real vortex: 0
    property real source: 0
    property real spacing: 0.12
    property real dash: 1
    property real travel: 0
    property real duty: 0.35
    property real density: 0.5
    property real lineWidth: 3.5
    property real sheet: 0.25
    property real inner: 0
    property real outer: 2
    property real mist: 0
    property real turbulence: 14
    property rect mask
    property real maskRadius: 10
    property var theme: null
    property color cBody: theme ? Qt.lighter(Colors.mix(theme.rosewater, theme.text, 0.15), 1.05) : "#f6f9fc"
    property color cRim: theme ? Colors.mix(theme.blue, theme.accent, 0.15) : "#7fa6c8"
    fragmentShader: Qt.resolvedUrl("qsb/Wind.qsb")
}
