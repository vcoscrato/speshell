import QtQuick
import "Water.js" as Water

// A water whip along a log spiral. See Whip.frag.
ShaderEffect {
    property real time: 0
    property size resolution: Qt.size(width, height)
    property point center
    property real r0: 600
    property real k: 0.35
    property real th0: 0
    property real spin: 1
    property real head: 0
    property real len: 3
    property real tubeWidth: 16
    property var theme: null
    property color cDeep: Water.deep(theme)
    property color cMid: Water.mid(theme)
    property color cLight: Water.light(theme)
    property color cFoam: Water.foam(theme)
    fragmentShader: Qt.resolvedUrl("qsb/Whip.qsb")
}
