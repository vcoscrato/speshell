import QtQuick
import qs.services

// Info icon that explains the item beside it while hovered.
Item {
    id: root

    property string text: ""

    implicitWidth: Theme.iconSizeTiny + Theme.spacingTiny * 2
    implicitHeight: implicitWidth

    Accessible.role: Accessible.StaticText
    Accessible.name: root.text

    HoverHandler {
        id: hover
        cursorShape: Qt.WhatsThisCursor
    }

    AppIcon {
        anchors.centerIn: parent
        name: "info"
        size: Theme.iconSizeTiny
        iconColor: hover.hovered ? Theme.text : Theme.overlay
    }

    Tooltip {
        visible: hover.hovered && root.text !== ""
        delay: 150
        text: root.text
    }
}
