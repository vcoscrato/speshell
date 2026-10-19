import QtQuick
import qs.services
import qs.theme

// A tile that runs something, in a tone: an icon disc, a title over a detail line, and
// an optional secondary button. Hovered it tints in its tone, and `active` (running, or
// armed to confirm) fills it; `busy` spins its icon and takes no clicks. While active,
// `countdownMs` drains a line along its foot.
Rectangle {
    id: root

    property string label: ""
    property string detail: ""
    property string iconName: ""
    property string tone: "accent"
    property bool active: false
    property bool busy: false
    property int countdownMs: 0
    property string secondaryIcon: ""
    property string secondaryText: ""

    readonly property color toneColor: Theme.toneColor(root.tone)
    readonly property bool hot: root.active || (mouse.containsMouse && root.enabled && !root.busy)

    signal activated()
    signal secondaryActivated()

    implicitHeight: Math.max(Theme.controlHeight, textColumn.implicitHeight) + Theme.spacingSmall * 2
    radius: Theme.borderRadius
    clip: true
    opacity: root.enabled ? 1 : Theme.disabledOpacity
    color: root.active ? Theme.alpha(root.toneColor, Theme.tintStrong)
        : root.hot ? Theme.alpha(root.toneColor, Theme.tintSubtle)
        : Theme.controlFill
    border.width: Theme.borderWidth
    border.color: root.active ? Theme.alpha(root.toneColor, Theme.tintOutlineStrong)
        : root.hot ? Theme.alpha(root.toneColor, Theme.tintOutline)
        : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animDurationFast }
    }

    Accessible.role: Accessible.Button
    Accessible.name: root.label
    Accessible.description: root.detail
    Accessible.onPressAction: if (root.enabled && !root.busy) root.activated()

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: root.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: {
            if (root.busy)
                return;
            EffectsService.picked(root, mouse);
            root.activated();
        }
    }

    IconDisc {
        id: disc
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingSmall
        anchors.verticalCenter: parent.verticalCenter
        iconName: root.iconName
        toneColor: root.toneColor
        lit: root.hot
        spinning: root.busy
    }

    Column {
        id: textColumn
        anchors.left: disc.right
        anchors.leftMargin: Theme.spacingSmall
        anchors.right: secondary.visible ? secondary.left : parent.right
        anchors.rightMargin: Theme.spacingSmall
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingMicro

        Label {
            role: "title"
            width: parent.width
            text: root.label
            elide: Text.ElideRight
        }

        Label {
            role: "caption"
            width: parent.width
            text: root.detail
            color: root.active ? root.toneColor : Theme.subtext
            elide: Text.ElideRight
        }
    }

    IconButton {
        id: secondary
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingSmall
        anchors.verticalCenter: parent.verticalCenter
        visible: root.secondaryIcon !== ""
        iconName: root.secondaryIcon
        iconSize: Theme.iconSizeSmall
        iconColor: secondary.containsMouse ? root.toneColor : Theme.subtextBright
        hoverColor: Theme.alpha(root.toneColor, Theme.tintStrong)
        tooltipText: root.secondaryText
        onClicked: root.secondaryActivated()
    }

    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        height: 2
        color: root.toneColor
        visible: root.active && root.countdownMs > 0

        NumberAnimation on width {
            running: root.active && root.countdownMs > 0
            from: root.width
            to: 0
            duration: root.countdownMs
        }
    }
}
