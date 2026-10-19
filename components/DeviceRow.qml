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

    width: parent ? parent.width : 300
    implicitHeight: contentColumn.implicitHeight + Theme.spacingSmall * 2
    radius: Theme.borderRadius
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

            IconDisc {
                id: iconDisc
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                iconName: root.busy ? "loader" : root.iconName
                lit: root.current
                spinning: root.busy
            }

            Column {
                id: textColumn
                anchors.left: iconDisc.right
                anchors.leftMargin: Theme.spacingMedium
                anchors.right: actionRow.left
                anchors.rightMargin: actionRow.width > 0 ? Theme.spacingSmall : 0
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingMicro

                Label {
                    role: "title"
                    width: parent.width
                    text: root.title
                    elide: Text.ElideRight
                }

                Label {
                    role: "caption"
                    width: parent.width
                    text: root.subtitle
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
