import QtQuick
import qs.theme

Item {
    id: root

    default property alias content: contentColumn.data
    property alias pinnedContent: pinnedColumn.data
    property alias headerActions: headerActionsRow.data
    property string title: ""
    property string iconName: ""

    implicitWidth: Theme.panelWidth
    implicitHeight: container.implicitHeight

    // Don't animate implicitHeight: under Qt 6.12, animating this clipped card's
    // height over large content (a long Notes preview) segfaults the scene graph
    // renderer in QSGBatchRenderer::prepareAlphaBatches.
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

                Text {
                    text: root.title
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.8
                    color: Theme.subtext
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
