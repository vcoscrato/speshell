pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

// A device or network: an icon disc, a title over a detail line, and its actions.
// `current` marks the active connection; `busy` spins the icon while it changes.
Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property color subtitleColor: Theme.subtext
    property string iconName: ""
    property bool current: false
    property bool busy: false
    property bool primaryEnabled: true
    property var actions: [] // [{ text, kind, enabled, actionId }]

    default property alias expandedContent: expandedColumn.data

    signal primaryTriggered()
    signal actionTriggered(string actionId)

    // The spinner stops wherever it is; set the icon upright again.
    onBusyChanged: if (!root.busy) statusIcon.rotation = 0

    width: parent ? parent.width : 300
    implicitHeight: contentColumn.implicitHeight + Theme.spacingSmall * 2
    radius: Theme.borderRadiusSmall
    color: root.current
        ? Theme.selectedFill
        : (rowMouse.containsMouse && root.primaryEnabled ? Theme.controlFill : "transparent")
    border.width: Theme.borderWidth
    border.color: root.current ? Theme.selectedBorder : "transparent"

    Accessible.role: Accessible.Button
    Accessible.name: root.title
    Accessible.description: root.subtitle
    Accessible.onPressAction: if (root.primaryEnabled) root.primaryTriggered()

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.primaryEnabled
        cursorShape: root.primaryEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.primaryTriggered()
    }

    Column {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spacingSmall
        spacing: Theme.spacingSmall

        Item {
            width: parent.width
            height: Math.max(iconDisc.height, textColumn.implicitHeight)

            Rectangle {
                id: iconDisc
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.controlHeight
                height: width
                radius: width / 2
                color: Theme.alpha(root.current ? Theme.accent : Theme.overlay,
                    root.current ? Theme.tintStrong : Theme.tintSubtle)

                AppIcon {
                    id: statusIcon
                    anchors.centerIn: parent
                    name: root.busy ? "loader" : root.iconName
                    size: Theme.iconSizeMedium
                    iconColor: root.current || root.busy ? Theme.accent : Theme.subtextBright

                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 1200
                        loops: Animation.Infinite
                        running: root.busy && root.visible
                    }
                }
            }

            Column {
                id: textColumn
                anchors.left: iconDisc.right
                anchors.leftMargin: Theme.spacingMedium
                anchors.right: actionRow.left
                anchors.rightMargin: actionRow.width > 0 ? Theme.spacingSmall : 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingMicro

                Text {
                    width: parent.width
                    text: root.title
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily
                    font.weight: root.current ? Font.DemiBold : Font.Medium
                    color: Theme.text
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.subtitle
                    font.pixelSize: Theme.fontSizeCaption
                    font.family: Theme.fontFamily
                    color: root.subtitleColor
                    elide: Text.ElideRight
                    visible: text !== ""
                }
            }

            Row {
                id: actionRow
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingTiny

                Repeater {
                    model: root.actions
                    delegate: ActionButton {
                        id: action
                        required property var modelData
                        anchors.verticalCenter: parent.verticalCenter
                        text: action.modelData.text || ""
                        kind: action.modelData.kind || "secondary"
                        compact: true
                        enabled: action.modelData.enabled !== false
                        onClicked: root.actionTriggered(action.modelData.actionId || "")
                    }
                }
            }
        }

        Column {
            id: expandedColumn
            width: parent.width
            spacing: Theme.spacingSmall
        }
    }
}
