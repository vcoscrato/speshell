import QtQuick
import qs.services

// A card in the middle of the screen, rounded on every corner: an icon in its tone and a
// title over a detail, then the children.
Surface {
    id: root

    property string iconName: ""
    property color toneColor: Theme.accent
    property string title: ""
    property string detail: ""
    default property alias content: body.data

    anchors.centerIn: parent
    height: column.implicitHeight + Theme.spacingXL * 2
    backdrop: true
    rounded: true

    Column {
        id: column
        x: Theme.spacingXL
        y: Theme.spacingXL
        width: parent.width - Theme.spacingXL * 2
        spacing: Theme.spacingLarge

        Row {
            width: parent.width
            spacing: Theme.spacingMedium

            AppIcon {
                id: icon
                anchors.verticalCenter: parent.verticalCenter
                name: root.iconName
                size: Theme.iconSizeLarge
                iconColor: root.toneColor
            }

            Column {
                width: parent.width - icon.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingMicro

                Label {
                    role: "heading"
                    width: parent.width
                    text: root.title
                    wrapMode: Text.Wrap
                }

                Label {
                    width: parent.width
                    visible: text !== ""
                    text: root.detail
                    color: Theme.subtext
                    wrapMode: Text.Wrap
                }
            }
        }

        Column {
            id: body
            width: parent.width
            spacing: Theme.spacingMedium
        }
    }
}
