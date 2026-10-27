import QtQuick
import qs.services

// What a panel shows when it has nothing to list: an icon disc, a title, a hint, and
// optionally the one action that would fill it.
Item {
    id: root

    property string iconName: ""
    property string title: ""
    property string detail: ""
    property string actionLabel: ""
    property string actionIconName: ""
    property bool busy: false

    signal activated()

    width: parent ? parent.width : 300
    implicitHeight: column.implicitHeight + Theme.spacingXL * 2
    height: implicitHeight

    Column {
        id: column
        anchors.centerIn: parent
        width: Math.min(parent.width, 300)
        spacing: Theme.spacingSmall

        IconDisc {
            anchors.horizontalCenter: parent.horizontalCenter
            size: Theme.controlHeight * 1.5
            iconName: root.busy ? "loader" : root.iconName
            spinning: root.busy
        }

        Item { width: 1; height: Theme.spacingTiny }

        Label {
            role: "title"
            width: parent.width
            text: root.title
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Label {
            width: parent.width
            text: root.detail
            horizontalAlignment: Text.AlignHCenter
            color: Theme.subtext
            wrapMode: Text.WordWrap
            visible: text !== ""
        }

        Item {
            width: 1
            height: Theme.spacingTiny
            visible: action.visible
        }

        ActionButton {
            id: action
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.actionLabel !== ""
            text: root.actionLabel
            iconName: root.actionIconName
            kind: "primary"
            onClicked: root.activated()
        }
    }
}
