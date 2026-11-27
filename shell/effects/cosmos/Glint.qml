import QtQuick

// A star glint centered on (cx, cy).
ShaderEffect {
    id: root
    property real cx: 0
    property real cy: 0
    property real size
    property real k: 0
    property real spin
    property color cHot
    property color cGlow

    visible: root.k > 0.001
    x: root.cx - root.size / 2
    y: root.cy - root.size / 2
    width: root.size
    height: root.size
    fragmentShader: Qt.resolvedUrl("qsb/Glint.qsb")
}
