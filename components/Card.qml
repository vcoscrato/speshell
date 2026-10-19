import QtQuick
import qs.theme

// A panel's body: an optional header with an icon, a title, and actions, then content
// pinned at the top and the rest below.
Item {
    id: root

    default property alias content: contentColumn.data
    property alias pinnedContent: pinnedColumn.data
    property alias headerActions: headerActionsRow.data
    property string title: ""
    property string iconName: ""

    implicitWidth: Theme.panelWidth
    implicitHeight: container.implicitHeight

    // Its height follows the content at once; the dropdown hosting it animates.
    clip: true

    Column {
        id: container
        anchors.fill: parent
        spacing: Theme.spacingSmall

        // Header (optional)
        Item {
            visible: root.title !== ""
            width: parent.width
            height: visible ? Math.max(20, leftTitleRow.height, headerActionsRow.height) : 0

            Row {
                id: leftTitleRow
                spacing: Theme.spacingSmall
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                AppIcon {
                    name: root.iconName
                    size: Theme.iconSizeSmall
                    iconColor: Theme.subtext
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.iconName !== ""
                }

                Label {
                    role: "section"
                    text: root.title
                }
            }

            Row {
                id: headerActionsRow
                spacing: Theme.spacingSmall
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Column {
            id: pinnedColumn
            width: parent.width
            spacing: Theme.spacingSmall
        }

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.spacingSmall
        }
    }
}
