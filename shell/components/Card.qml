import QtQuick
import qs.services

// A panel's body: an optional header with an icon, a title, and actions, then content
// pinned at the top and the rest below.
Item {
    id: root

    default property alias content: contentColumn.data
    property alias pinnedContent: pinnedColumn.data
    property alias headerActions: headerActionsRow.data
    // The PanelService panel it is, which names it and gives its icon.
    property string panel: ""
    property string title: PanelService.has(root.panel) ? PanelService.panels[root.panel].label : ""
    property string iconName: PanelService.has(root.panel) ? PanelService.panels[root.panel].icon : ""
    // How many the panel holds, in a pill beside the title; 0 shows none.
    property int count: 0

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
            // As tall as a header button, whether or not it has one.
            height: visible ? Math.max(Theme.controlHeightSmall, leftTitleRow.height, headerActionsRow.height) : 0

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
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.title
                }

                Pill {
                    visible: root.count > 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.count
                    toneColor: Theme.overlay
                    textColor: Theme.subtext
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
