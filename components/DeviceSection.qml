import QtQuick
import qs.theme

// A labelled group of device rows: title, count, and an optional status on the right.
Item {
    id: root

    property string title: ""
    property int count: 0
    property string status: ""
    property bool statusActive: false

    width: parent ? parent.width : 300
    implicitHeight: Math.max(22, sectionRow.implicitHeight + Theme.spacingTiny)
    height: implicitHeight

    Row {
        id: sectionRow

        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingSmall

        Text {
            text: root.title
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            font.bold: true
            color: Theme.subtext
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            visible: root.count > 0
            radius: Theme.borderRadiusSmall
            height: Math.max(16, countText.implicitHeight + Theme.spacingTiny)
            width: countText.width + 10
            color: Theme.alpha(Theme.overlay, Theme.tintStrong)
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: countText
                anchors.centerIn: parent
                text: root.count
                font.pixelSize: Theme.fontSizeMicro
                font.family: Theme.fontFamily
                color: Theme.subtext
            }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.status
        font.pixelSize: Theme.fontSizeCaption
        font.family: Theme.fontFamily
        color: root.statusActive ? Theme.accent : Theme.overlay
        visible: text !== ""
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Theme.separatorThickness
        color: Theme.controlFill
    }
}
