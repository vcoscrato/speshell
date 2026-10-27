import QtQuick
import QtQuick.Templates as T
import qs.services

// A row of PopupMenu: an optional icon and the label, then a check on selectable rows or
// an arrow when it opens a submenu. `selected` marks the current choice; a click never
// toggles it.
T.MenuItem {
    id: root

    property bool selectable: false
    property bool selected: false

    implicitWidth: Math.max(implicitBackgroundWidth, implicitContentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(implicitBackgroundHeight, implicitContentHeight + topPadding + bottomPadding)
    horizontalPadding: Theme.spacingSmall
    verticalPadding: Theme.spacingMicro
    spacing: Theme.spacingSmall
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSizeSmall
    icon.width: Theme.iconSizeSmall
    icon.height: Theme.iconSizeSmall
    opacity: root.enabled ? 1.0 : Theme.disabledOpacity

    Accessible.checkable: root.selectable
    Accessible.checked: root.selected

    contentItem: Item {
        implicitWidth: labelRow.implicitWidth + (marker.visible ? root.spacing + marker.width : 0)
        implicitHeight: Math.max(Theme.controlHeightSmall, labelRow.implicitHeight)

        Row {
            id: labelRow

            anchors.verticalCenter: parent.verticalCenter
            spacing: root.spacing

            Image {
                anchors.verticalCenter: parent.verticalCenter
                visible: String(root.icon.source) !== ""
                width: root.icon.width
                height: root.icon.height
                source: root.icon.source
                sourceSize: Qt.size(root.icon.width * 2, root.icon.height * 2)
                fillMode: Image.PreserveAspectFit
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.text
                textFormat: Text.PlainText
                font: root.font
                color: root.selected ? Theme.accent : Theme.text
            }
        }

        AppIcon {
            id: marker

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.subMenu !== null || root.selectable
            name: root.subMenu !== null ? "chevron-right" : "check"
            size: Theme.iconSizeTiny
            iconColor: root.subMenu !== null ? Theme.subtext : Theme.accent
            opacity: root.subMenu !== null || root.selected ? 1.0 : 0.0
        }
    }

    background: Rectangle {
        radius: Theme.borderRadius
        color: root.highlighted && root.enabled ? Theme.cardHover : "transparent"
    }
}
