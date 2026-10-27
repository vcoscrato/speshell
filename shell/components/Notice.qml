import QtQuick
import qs.services

// A warning or error inline: an alert icon, an optional bold heading, and its detail.
Rectangle {
    id: root

    property string heading: ""
    property string detail: ""
    property color toneColor: Theme.warning

    width: parent ? parent.width : 0
    implicitHeight: noticeText.implicitHeight + Theme.spacingSmall * 2
    radius: Theme.borderRadius
    color: Theme.alpha(root.toneColor, Theme.tintSubtle)
    border.width: Theme.borderWidth
    border.color: Theme.alpha(root.toneColor, Theme.tintOutline)

    AppIcon {
        id: noticeIcon
        x: Theme.spacingSmall
        y: Theme.spacingSmall + Math.max(0, (noticeMetrics.height - height) / 2)
        name: "alert"
        size: Theme.iconSizeSmall
        iconColor: root.toneColor
    }

    FontMetrics {
        id: noticeMetrics
        font.pixelSize: Theme.fontSizeSmall
        font.family: Theme.fontFamily
    }

    Column {
        id: noticeText
        anchors.left: noticeIcon.right
        anchors.leftMargin: Theme.spacingSmall
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingSmall
        y: Theme.spacingSmall
        spacing: Theme.spacingMicro

        Label {
            width: parent.width
            visible: root.heading !== ""
            text: root.heading
            font.weight: Font.Bold
            color: root.toneColor
            wrapMode: Text.WordWrap
        }

        Label {
            width: parent.width
            text: root.detail
            color: root.heading !== "" ? Theme.text : root.toneColor
            wrapMode: Text.Wrap
        }
    }
}
