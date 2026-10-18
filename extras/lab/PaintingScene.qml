import QtQuick
import Quickshell

// One painting (PAINTING, a compiled shader) at WIDTH x HEIGHT.
Item {
    width: Number(Quickshell.env("WIDTH") || 3840)
    height: Number(Quickshell.env("HEIGHT") || 2160)
    property real labTime: 0

    ShaderEffect {
        anchors.fill: parent
        property size resolution: Qt.size(width, height)
        fragmentShader: "file://" + Quickshell.env("PAINTING")
    }
}
