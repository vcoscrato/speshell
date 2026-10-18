import QtQuick
import qs.theme

Rectangle {
    id: root

    property string label: ""
    property string value: ""
    signal activated()

    width: parent ? parent.width : 300
    implicitHeight: Math.max(Theme.controlHeight, Math.max(labelText.implicitHeight, valueRow.implicitHeight)
        + Theme.spacingSmall * 2)
    height: implicitHeight
    radius: Theme.borderRadiusSmall
    opacity: root.enabled ? 1.0 : Theme.disabledOpacity
    color: selectMouse.containsMouse && root.enabled
        ? Theme.controlFill
        : "transparent"

    Accessible.role: Accessible.Button
    Accessible.name: root.label
    Accessible.description: root.value
    Accessible.onPressAction: {
        if (root.enabled)
            root.activated();
    }

    Text {
        id: labelText

        text: root.label
        font.pixelSize: Theme.fontSizeSmall
        font.family: Theme.fontFamily
        color: Theme.subtext
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingSmall
        anchors.right: valueRow.left
        anchors.rightMargin: Theme.spacingSmall
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
    }

    Row {
        id: valueRow

        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingSmall
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingTiny

        Text {
            width: Math.min(180, implicitWidth)
            text: root.value
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            font.bold: true
            color: Theme.text
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
        }

        AppIcon {
            name: "chevron-down"
            size: Theme.iconSizeTiny
            iconColor: Theme.subtext
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: selectMouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.activated()
    }
}
