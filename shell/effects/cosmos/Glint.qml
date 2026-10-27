import QtQuick

// A star glint centered on (cx, cy).
ShaderEffect {
    id: root
    property real cx: 0
    property real cy: 0
    property real size: 160
    property real k: 0
    property real spin: 0.2
    property color cHot: "#fbf1c7"
    property color cGlow: "#fabd2f"

    visible: root.k > 0.001
    x: root.cx - root.size / 2
    y: root.cy - root.size / 2
    width: root.size
    height: root.size
    fragmentShader: Qt.resolvedUrl("qsb/Glint.qsb")
}
