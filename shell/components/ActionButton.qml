import QtQuick
import QtQuick.Shapes
import qs.services

// Speshell's text button, in one of four kinds:
// "secondary", the default, on the control fill; "primary", the one action a panel or
// prompt leads with, in the accent; "danger", for an action that ends or throws something
// away; and "flat", filled only while hovered, as a value in a header that opens its
// editor. `checked` marks a button that turns something on, like Do Not Disturb, while
// it's on. Narrower than its text, it elides it.
Item {
    id: root

    property string text: ""
    property string iconName: ""
    property string kind: "secondary"
    property bool checked: false
    // Short, for card headers and inline rows.
    property bool compact: false
    property string tooltipText: ""
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed

    readonly property bool primary: root.kind === "primary"
    readonly property bool danger: root.kind === "danger"
    readonly property bool flat: root.kind === "flat"
    readonly property real padding: root.compact ? Theme.spacingSmall : Theme.spacingMedium
    readonly property color labelColor: root.primary ? Theme.onAccent
        : root.danger ? Theme.error
        : root.checked || root.hovered ? Theme.accent
        : Theme.text

    signal clicked()

    implicitWidth: Math.max(root.height, root.padding * 2 + (icon.visible ? icon.width : 0)
        + (icon.visible && label.visible ? content.spacing : 0) + (label.visible ? label.implicitWidth : 0))
    implicitHeight: Math.max(root.compact ? Theme.controlHeightSmall : Theme.controlHeight,
        labelMetrics.height + Theme.spacingSmall * 2)
    opacity: root.enabled ? 1 : Theme.disabledOpacity
    scale: root.pressed ? Theme.pressScale : 1

    Behavior on scale {
        NumberAnimation { duration: Theme.animDurationFast; easing.type: Theme.animEasing }
    }

    Accessible.role: Accessible.Button
    Accessible.name: root.text || root.tooltipText
    Accessible.checkable: root.checked
    Accessible.checked: root.checked
    Accessible.onPressAction: if (root.enabled) root.clicked()

    FontMetrics {
        id: labelMetrics
        font.pixelSize: Theme.fontSizeSmall
        font.family: Theme.fontFamily
        font.weight: Font.DemiBold
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.primary ? (root.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
                : root.danger ? Theme.alpha(Theme.error, root.hovered ? Theme.tintStrong : Theme.tintSubtle)
                : root.checked ? Theme.selectedFill
                : root.hovered ? Theme.cardHover
                : root.flat ? "transparent"
                : Theme.controlFill
            strokeWidth: Theme.borderWidth
            strokeColor: root.primary ? Theme.alpha(Qt.darker(Theme.accent, 1.6), 0.6)
                : root.danger ? Theme.alpha(Theme.error, root.hovered ? Theme.tintOutlineStrong : Theme.tintOutline)
                : root.checked ? Theme.selectedBorder
                : root.hovered ? Theme.alpha(Theme.accent, Theme.tintOutline)
                : root.flat ? "transparent"
                : Theme.controlBorder

            // Inside the button, so the outline lands on whole pixels.
            PathRectangle {
                width: root.width
                height: root.height
                radius: Theme.borderRadius
                strokeAdjustment: Theme.borderWidth
            }
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.spacingTiny

        AppIcon {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            visible: root.iconName !== ""
            name: root.iconName
            size: Theme.iconSizeSmall
            iconColor: root.labelColor
        }

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            visible: root.text !== ""
            width: Math.min(implicitWidth,
                root.width - root.padding * 2 - (icon.visible ? icon.width + content.spacing : 0))
            text: root.text
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font: labelMetrics.font
            color: root.labelColor
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            EffectsService.picked(root, mouse);
            root.clicked();
        }
    }

    Tooltip {
        visible: root.tooltipText !== "" && mouse.containsMouse
        text: root.tooltipText
    }
}
