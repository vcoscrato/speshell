import QtQuick
import qs.services

// The heading of a group of device rows: title, count, and an optional status on the
// right, over a rule, with room below it before the rows.
Item {
    id: root

    property string title: ""
    property int count: 0
    property string status: ""
    property bool statusActive: false

    width: parent?.width ?? 0
    // As tall with the count as without.
    implicitHeight: Math.max(countPill.implicitHeight, titleLabel.implicitHeight) + Theme.spacingTiny * 2
    height: implicitHeight

    Row {
        id: sectionRow

        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -Theme.spacingTiny / 2
        spacing: Theme.spacingSmall

        Label {
            id: titleLabel
            role: "section"
            text: root.title
            anchors.verticalCenter: parent.verticalCenter
        }

        Pill {
            id: countPill
            visible: root.count > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.count
            toneColor: Theme.overlay
            textColor: Theme.subtext
        }
    }

    Label {
        role: "caption"
        anchors.right: parent.right
        anchors.verticalCenter: sectionRow.verticalCenter
        text: root.status
        color: root.statusActive ? Theme.accent : Theme.overlay
        visible: text !== ""
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spacingTiny
        height: Theme.separatorThickness
        color: Theme.controlFill
    }
}
