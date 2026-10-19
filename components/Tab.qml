import QtQuick
import qs.services
import qs.theme

// One tab of a row of them: an icon, a label, or both, filled in the accent while it's
// the current one. A tab without its label names itself in a tooltip.
Rectangle {
    id: root

    property string text: ""
    property string iconName: ""
    property bool current: false
    // Hide the label, as a row short of space does for the tabs that aren't current.
    property bool showText: true
    // Room kept at the right end for a control of the tab's own, like a close button.
    property int trailingSpace: 0
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed
    readonly property bool labelShown: root.showText && root.text !== ""

    signal clicked()

    // From the label's natural width, which its shown width doesn't feed back into.
    implicitWidth: (root.iconName !== "" ? Theme.iconSizeSmall : 0)
        + (root.iconName !== "" && root.labelShown ? content.spacing : 0)
        + (root.labelShown ? label.implicitWidth : 0)
        + Theme.spacingSmall * 2 + root.trailingSpace
    implicitHeight: Theme.controlHeightSmall
    radius: Theme.borderRadius
    opacity: root.enabled ? 1 : Theme.disabledOpacity
    scale: root.pressed ? Theme.pressScale : 1
    color: root.current ? Theme.alpha(Theme.accent, Theme.tintStrong)
        : root.hovered ? Theme.cardHover
        : Theme.controlFill
    border.width: Theme.borderWidth
    border.color: root.current ? Theme.selectedBorder : "transparent"
    clip: true

    Behavior on scale {
        NumberAnimation { duration: Theme.animDurationFast; easing.type: Theme.animEasing }
    }

    Accessible.role: Accessible.PageTab
    Accessible.name: root.text
    Accessible.selected: root.current
    Accessible.onPressAction: if (root.enabled) root.clicked()

    Row {
        id: content
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -root.trailingSpace / 2
        spacing: Theme.spacingTiny

        AppIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.iconName !== ""
            name: root.iconName
            size: Theme.iconSizeSmall
            iconColor: root.current ? Theme.accent : root.hovered ? Theme.text : Theme.subtext
        }

        Label {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.width - Theme.spacingSmall * 2 - root.trailingSpace
                - (root.iconName !== "" ? Theme.iconSizeSmall + content.spacing : 0))
            visible: root.labelShown
            text: root.text
            elide: Text.ElideRight
            color: root.current ? Theme.text : Theme.subtext
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (!root.current)
                EffectsService.picked(root, mouse);
            root.clicked();
        }
    }

    Tooltip {
        visible: !root.labelShown && root.text !== "" && mouse.containsMouse
        text: root.text
    }
}
