import QtQuick
import QtQuick.Shapes
import qs.services
import qs.theme

// Speshell's text button, cut on two corners like its surfaces, in one of three kinds:
// "secondary", the default, on the control fill; "primary", the one action a panel or
// prompt leads with, wearing the theme effects' button face or else the accent; and
// "danger", for an action that ends or throws something away. `checked` marks a button
// that turns something on, like Do Not Disturb, while it's on.
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
    // The face shows once it loads; until then, and without one, the accent fills in.
    readonly property bool hasFace: root.primary && face.status === Loader.Ready
    readonly property color labelColor: root.primary ? Theme.onAccent
        : root.danger ? Theme.error
        : root.checked || root.hovered ? Theme.accent
        : Theme.text
    readonly property int cut: Math.round(root.height / 5)

    signal clicked()

    implicitWidth: Math.max(root.height, content.implicitWidth + (root.compact ? Theme.spacingSmall : Theme.spacingMedium) * 2)
    implicitHeight: Math.max(root.compact ? Theme.controlHeightSmall : Theme.controlHeight,
        labelMetrics.height + Theme.spacingSmall * 2)
    opacity: root.enabled ? 1 : Theme.disabledOpacity
    scale: root.pressed ? 0.96 : 1

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

    // The theme effects' face, drawn into a texture the outline clips.
    Loader {
        id: face
        // EffectClock runs at this speed and frame rate.
        property real timeScale: 1
        property int frameRate: EffectsService.frameRate

        width: root.width
        height: root.height
        active: root.primary
        sourceComponent: EffectsService.button
    }

    Binding { target: face.item; property: "theme"; value: Theme }
    Binding { target: face.item; property: "hovered"; value: root.hovered && root.enabled }
    Binding { target: face.item; property: "pressed"; value: root.pressed }
    Binding { target: face.item; property: "pointer"; value: Qt.point(mouse.mouseX, mouse.mouseY) }
    Binding { target: face.item; property: "running"; value: Theme.motion }

    ShaderEffectSource {
        id: faceTexture
        visible: false
        sourceItem: root.hasFace ? face : null
        hideSource: true
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: outline

            // Half a pixel in, so the outline lands on whole pixels.
            readonly property real w: root.width - 0.5
            readonly property real h: root.height - 0.5

            fillColor: root.primary ? (root.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)
                : root.danger ? Theme.alpha(Theme.error, root.hovered ? Theme.tintStrong : Theme.tintSubtle)
                : root.checked ? Theme.selectedFill
                : root.hovered ? Theme.cardHover
                : Theme.controlFill
            fillItem: root.hasFace ? faceTexture : null
            strokeWidth: Theme.borderWidth
            strokeColor: root.primary ? Theme.alpha(Qt.darker(Theme.accent, 1.6), 0.6)
                : root.danger ? Theme.alpha(Theme.error, root.hovered ? Theme.tintOutlineStrong : Theme.tintOutline)
                : root.checked ? Theme.selectedBorder
                : root.hovered ? Theme.alpha(Theme.accent, Theme.tintOutline)
                : Theme.controlBorder
            joinStyle: ShapePath.MiterJoin

            PathPolyline {
                path: [
                    Qt.point(0.5 + root.cut, 0.5),
                    Qt.point(outline.w, 0.5),
                    Qt.point(outline.w, outline.h - root.cut),
                    Qt.point(outline.w - root.cut, outline.h),
                    Qt.point(0.5, outline.h),
                    Qt.point(0.5, 0.5 + root.cut),
                    Qt.point(0.5 + root.cut, 0.5)
                ]
            }
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: Theme.spacingTiny

        AppIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.iconName !== ""
            name: root.iconName
            size: Theme.iconSizeSmall
            iconColor: root.labelColor
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.text !== ""
            text: root.text
            textFormat: Text.PlainText
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
