import QtQuick
import qs.theme

// A square button that shows only an icon, filled while hovered, and its tooltip.
Rectangle {
    id: root

    property string iconName: ""
    property int iconSize: Theme.iconSizeMedium
    property color iconColor: Theme.text
    property color hoverColor: Theme.cardHover
    property real size: Theme.controlHeight
    property real iconXOffset: 0
    property bool iconSpinning: false
    property string tooltipText: ""
    property alias containsMouse: mouseArea.containsMouse

    signal clicked()

    width: size
    height: size
    radius: Theme.borderRadius
    opacity: enabled ? 1.0 : Theme.disabledOpacity
    scale: mouseArea.pressed ? Theme.pressScale : 1
    color: mouseArea.containsMouse && root.enabled ? root.hoverColor : "transparent"

    Behavior on scale {
        NumberAnimation { duration: Theme.animDurationFast; easing.type: Theme.animEasing }
    }

    Accessible.role: Accessible.Button
    Accessible.name: root.tooltipText !== ""
        ? root.tooltipText
        : root.iconName
    Accessible.onPressAction: {
        if (root.enabled)
            root.clicked();
    }

    AppIcon {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.iconXOffset
        name: root.iconName
        size: root.iconSize
        iconColor: root.iconColor
        spinning: root.iconSpinning
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        hoverEnabled: true
        onClicked: root.clicked()
    }

    Tooltip {
        visible: root.tooltipText !== "" && mouseArea.containsMouse
        text: root.tooltipText
    }
}
