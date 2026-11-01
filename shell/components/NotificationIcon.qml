import QtQuick
import qs.services

// A notification's image or its app's icon; Speshell's mark on its own notices, and a
// bell for an app without an icon.
Item {
    id: root

    required property var notification
    property real size: Theme.iconSizeMedium
    readonly property bool internal: NotificationService.isInternal(root.notification)

    width: root.size
    height: root.size

    Image {
        id: image
        anchors.fill: parent
        source: NotificationService.iconSource(root.notification)
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        fillMode: Image.PreserveAspectFit
        visible: status === Image.Ready
    }

    SpeshellMark {
        anchors.centerIn: parent
        size: root.size - 2
        visible: !image.visible && root.internal
    }

    AppIcon {
        anchors.centerIn: parent
        name: "bell"
        size: Theme.iconSizeSmall
        iconColor: Theme.overlay
        visible: !image.visible && !root.internal
    }
}
