import QtQuick
import qs.services

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

        Label {
            role: "section"
            text: root.title
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            visible: root.count > 0
            radius: Theme.borderRadius
            height: Math.max(16, countText.implicitHeight + Theme.spacingTiny)
            width: countText.width + 10
            color: Theme.alpha(Theme.overlay, Theme.tintStrong)
            anchors.verticalCenter: parent.verticalCenter

            Label {
                id: countText
                anchors.centerIn: parent
                text: root.count
                font.pixelSize: Theme.fontSizeMicro
                color: Theme.subtext
            }
        }
    }

    Label {
        role: "caption"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.status
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
