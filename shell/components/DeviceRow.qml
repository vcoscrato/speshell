pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import "Keyboard.js" as Keyboard

// A device or network: an icon disc, a title over a detail line, and its actions at the
// right edge, flush with the panel's header. `current` marks the device in use or the
// active connection, lighting the disc and checking the row; `busy` spins the disc while
// it changes. Rows are as tall with a detail line as without. What the row holds (a
// password prompt, an error) lines up under its title. Space or Enter picks it from the
// keyboard.
Item {
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
    // Under the pointer, its actions too, for actions shown only on hover.
    readonly property alias hovered: rowHover.hovered

    signal primaryTriggered()
    signal actionTriggered(string actionId)

    width: parent?.width ?? 0
    implicitHeight: contentColumn.implicitHeight + Theme.spacingTiny * 2
    activeFocusOnTab: root.primaryEnabled

    Accessible.role: Accessible.Button
    Accessible.name: root.title
    Accessible.description: root.subtitle
    Accessible.onPressAction: if (root.primaryEnabled) root.primaryTriggered()
    Keys.onPressed: event => {
        if (root.primaryEnabled && Keyboard.presses(event)) {
            event.accepted = true;
            if (!root.current)
                EffectsService.picked(iconDisc, null);
            root.primaryTriggered();
        }
    }

    HoverHandler {
        id: rowHover
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.primaryEnabled
        cursorShape: root.primaryEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (!root.current)
                EffectsService.picked(iconDisc, rowMouse);
            root.primaryTriggered();
        }
    }

    Column {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Theme.spacingTiny
        spacing: Theme.spacingSmall

        // As tall as a title over a detail line, whether or not there is one.
        Item {
            width: parent.width
            height: Math.max(iconDisc.height, titleLabel.implicitHeight + textColumn.spacing + subtitleLabel.implicitHeight)

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
                    id: titleLabel
                    role: "title"
                    width: parent.width
                    text: root.title
                    color: rowMouse.containsMouse && root.primaryEnabled ? Theme.accent : Theme.text
                    elide: Text.ElideRight
                }

                Label {
                    id: subtitleLabel
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

                AppIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.current && !root.busy
                    name: "check"
                    size: Theme.iconSizeSmall
                    iconColor: Theme.accent
                }

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
            x: iconDisc.width + Theme.spacingMedium
            width: parent.width - expandedColumn.x
            spacing: Theme.spacingSmall
        }
    }

    FocusRing {}
}
