import QtQuick
import qs.theme

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

    // The spinner stops wherever it is; set the icon upright again.
    onBusyChanged: if (!root.busy) statusIcon.rotation = 0

    width: parent ? parent.width : 300
    implicitHeight: column.implicitHeight + Theme.spacingXL * 2
    height: implicitHeight

    Column {
        id: column
        anchors.centerIn: parent
        width: Math.min(parent.width, 300)
        spacing: Theme.spacingSmall

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 48
            height: width
            radius: width / 2
            color: Theme.alpha(root.busy ? Theme.accent : Theme.overlay,
                Theme.tintSubtle)
            border.width: Theme.borderWidth
            border.color: Theme.alpha(root.busy ? Theme.accent : Theme.overlay,
                Theme.tintStrong)

            AppIcon {
                id: statusIcon
                anchors.centerIn: parent
                name: root.busy ? "loader" : root.iconName
                size: Theme.iconSizeLarge
                iconColor: root.busy ? Theme.accent : Theme.subtext

                RotationAnimator on rotation {
                    from: 0
                    to: 360
                    duration: 1200
                    loops: Animation.Infinite
                    running: root.busy && root.visible
                }
            }
        }

        Item { width: 1; height: Theme.spacingTiny }

        Text {
            width: parent.width
            text: root.title
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeNormal
            font.family: Theme.fontFamily
            font.weight: Font.DemiBold
            color: Theme.text
            wrapMode: Text.WordWrap
        }

        Text {
            width: parent.width
            text: root.detail
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
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
