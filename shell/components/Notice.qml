import QtQuick
import qs.services

// A warning or error inline: its icon, an optional bold heading, and its detail, with
// the children under them (buttons, say) and `trailing` at the right. `progress`, from
// 1 to 0, counts down along its foot, as the time left to undo.
Rectangle {
    id: root

    property string heading: ""
    property string detail: ""
    property color toneColor: Theme.warning
    property string iconName: "alert"
    // -1 for no countdown.
    property real progress: -1
    default property alias content: extra.data
    property alias trailing: trailingRow.data

    width: parent ? parent.width : 0
    implicitHeight: Math.max(noticeText.implicitHeight, trailingRow.height) + Theme.spacingSmall * 2
    radius: Theme.borderRadius
    color: Theme.alpha(root.toneColor, Theme.tintSubtle)
    border.width: Theme.borderWidth
    border.color: Theme.alpha(root.toneColor, Theme.tintOutline)
    clip: true

    Accessible.role: Accessible.AlertMessage
    Accessible.name: [root.heading, root.detail].filter(text => text !== "").join(". ")

    // On the first line.
    AppIcon {
        id: noticeIcon
        x: Theme.spacingSmall
        y: noticeText.y + Math.max(0, (noticeMetrics.height - height) / 2)
        name: root.iconName
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
        anchors.right: trailingRow.left
        anchors.rightMargin: Theme.spacingSmall
        y: (root.height - implicitHeight) / 2
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
            visible: text !== ""
            text: root.detail
            color: root.heading !== "" ? Theme.text : root.toneColor
            wrapMode: Text.Wrap
        }

        Column {
            id: extra
            width: parent.width
            topPadding: Theme.spacingTiny
            spacing: Theme.spacingSmall
            visible: children.length > 0
        }
    }

    Row {
        id: trailingRow
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingTiny
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingTiny
    }

    ProgressBar {
        visible: root.progress >= 0
        anchors.bottom: parent.bottom
        height: Theme.separatorThickness * 2
        color: "transparent"
        value: root.progress
        fillColor: root.toneColor
    }
}
