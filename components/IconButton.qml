import QtQuick
import qs.theme

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

    onIconSpinningChanged: if (!root.iconSpinning) iconContainer.rotation = 0

    width: size
    height: size
    radius: Theme.borderRadiusSmall
    opacity: enabled ? 1.0 : Theme.disabledOpacity
    color: mouseArea.containsMouse && root.enabled
        ? (mouseArea.pressed ? Theme.surface2 : root.hoverColor)
        : "transparent"

    Accessible.role: Accessible.Button
    Accessible.name: root.tooltipText !== ""
        ? root.tooltipText
        : root.iconName
    Accessible.onPressAction: {
        if (root.enabled)
            root.clicked();
    }

    Item {
        id: iconContainer
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.iconXOffset
        width: root.size
        height: root.size
        scale: mouseArea.pressed ? 0.85 : 1.0

        AppIcon {
            anchors.centerIn: parent
            name: root.iconName
            size: root.iconSize
            iconColor: root.iconColor
            visible: root.iconName !== ""
        }

        Behavior on scale {
            NumberAnimation { duration: Theme.animDurationFast; easing.type: Theme.animEasing }
        }

        RotationAnimator on rotation {
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            running: root.iconSpinning
        }
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
