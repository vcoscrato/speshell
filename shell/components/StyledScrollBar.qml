import QtQuick
import QtQuick.Templates as T
import qs.services

// Thin scroll handle, shown while the content overflows; for ScrollBar.vertical.
T.ScrollBar {
    id: root

    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: implicitContentHeight + topPadding + bottomPadding
    padding: Theme.spacingMicro
    visible: root.policy !== T.ScrollBar.AlwaysOff
    minimumSize: root.orientation === Qt.Horizontal ? root.height / root.width : root.width / root.height

    contentItem: Rectangle {
        implicitWidth: 4
        implicitHeight: 4
        radius: width / 2
        color: root.pressed ? Theme.subtext : Theme.overlay
        opacity: root.size < 1.0 ? (root.active ? 0.75 : 0.5) : 0.0

        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration }
        }
    }
}
