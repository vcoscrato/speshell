import QtQuick
import qs.services

// A short tag in its tone, as a count beside a heading or the displays' layout.
Rectangle {
    id: root

    property string text: ""
    property color toneColor: Theme.accent
    property color textColor: root.toneColor

    implicitWidth: label.implicitWidth + Theme.spacingSmall * 2
    implicitHeight: Math.max(18, label.implicitHeight + Theme.spacingTiny)
    radius: Theme.borderRadius
    color: Theme.alpha(root.toneColor, Theme.tintSubtle)
    border.width: Theme.borderWidth
    border.color: Theme.alpha(root.toneColor, Theme.tintOutline)

    Label {
        id: label
        role: "caption"
        anchors.centerIn: parent
        text: root.text
        font.weight: Font.Bold
        font.features: { "tnum": 1 }
        color: root.textColor
    }
}
