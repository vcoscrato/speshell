import QtQuick
import qs.services

// How far something has gone, `value` from 0 to 1, as a timer's time left or the
// countdown along a toast's, a notice's, or a tile's foot: the fill over its track.
Rectangle {
    id: root

    property real value: 0
    property color fillColor: Theme.accent

    width: parent ? parent.width : 0
    implicitHeight: Theme.spacingTiny
    radius: height / 2
    // The slider's track.
    color: Theme.alpha(Theme.surface2, 0.5)

    Rectangle {
        width: parent.width * Math.max(0, Math.min(1, root.value))
        height: parent.height
        radius: parent.radius
        color: root.fillColor
    }
}
