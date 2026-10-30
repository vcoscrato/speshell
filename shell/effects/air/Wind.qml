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
    // The turbulence, worked out at an eighth of the resolution (Wind.drift.frag).
    property var drift: driftTex
    fragmentShader: Qt.resolvedUrl("qsb/Wind.qsb")

    ShaderEffect {
        id: driftPass
        visible: parent.turbulence > 0
        width: Math.max(1, Math.ceil(parent.width / 8))
        height: Math.max(1, Math.ceil(parent.height / 8))
        blending: false
        property real time: parent.time
        property size area: Qt.size(parent.width, parent.height)
        property point origin: parent.origin
        property point center: parent.center
        property size axes: parent.axes
        property real turbulence: parent.turbulence
        fragmentShader: Qt.resolvedUrl("qsb/Wind.drift.qsb")
    }

    ShaderEffectSource {
        id: driftTex
        sourceItem: driftPass
        hideSource: true
        format: ShaderEffectSource.RGBA16F
        textureSize: Qt.size(driftPass.width, driftPass.height)
    }
}
