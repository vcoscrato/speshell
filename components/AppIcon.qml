import QtQuick
import QtQuick.Effects
import qs.theme
import "Icons.js" as Icons

// An icon from assets/icons by its name in Icons.js, tinted `iconColor`.
Item {
    id: root

    property string name: ""
    property color iconColor: Theme.text
    property real size: 20
    // Turns while something is busy, and stands upright again when it stops.
    property bool spinning: false
    readonly property string iconFile: Icons.fileFor(root.name)
    readonly property url iconSource: Qt.resolvedUrl("../assets/icons/" + root.iconFile + ".svg")

    width: root.size
    height: root.size
    visible: root.name !== ""

    onSpinningChanged: if (!root.spinning) root.rotation = 0

    RotationAnimator on rotation {
        from: 0
        to: 360
        duration: Theme.spinDuration
        loops: Animation.Infinite
        running: root.spinning && root.visible && Theme.motion
    }

    Image {
        id: iconImage
        anchors.fill: parent
        source: root.iconSource
        sourceSize: Qt.size(Math.ceil(root.size * 4), Math.ceil(root.size * 4))
        fillMode: Image.PreserveAspectFit
        asynchronous: false
        smooth: true
        mipmap: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: iconImage
        brightness: 1
        colorization: 1
        colorizationColor: root.iconColor
    }
}
