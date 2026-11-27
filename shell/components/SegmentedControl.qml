pragma ComponentBehavior: Bound
import QtQuick
import qs.services
import "Keyboard.js" as Keyboard

// Mutually exclusive choice among a few short options ({ value, label }).
// Segments share the width equally; nothing is highlighted for an unlisted value.
// The arrow keys pick the option beside the current one.
Rectangle {
    id: root

    property var options: []
    property var currentValue: undefined

    signal valueSelected(var selectedValue)

    // Picks the option `index`, as a click on it does.
    function pick(index, target, pointer) {
        if (index === root.currentIndex || index < 0 || index >= root.options.length)
            return;
        EffectsService.picked(target, pointer);
        root.valueSelected(root.options[index].value);
    }

    readonly property int inset: Theme.spacingMicro
    readonly property int currentIndex: {
        for (let i = 0; i < root.options.length; i++) {
            if (root.options[i].value === root.currentValue)
                return i;
        }
        return -1;
    }
    readonly property real naturalSegmentWidth: {
        // Reading the font keeps this current when the text scale changes.
        let widest = segmentMetrics.font.pixelSize * 0;
        for (let i = 0; i < root.options.length; i++)
            widest = Math.max(widest, segmentMetrics.advanceWidth(String(root.options[i].label)));
        return Math.ceil(widest) + Theme.spacingSmall * 2;
    }
    readonly property real segmentWidth: root.options.length > 0
        ? (root.width - root.inset * 2) / root.options.length
        : 0

    implicitWidth: root.naturalSegmentWidth * root.options.length + root.inset * 2
    implicitHeight: Math.max(Theme.controlHeightSmall, segmentMetrics.height + Theme.spacingTiny * 2)
        + root.inset * 2
    width: implicitWidth
    height: implicitHeight
    radius: Theme.borderRadius
    opacity: root.enabled ? 1.0 : Theme.disabledOpacity
    activeFocusOnTab: true
    color: Theme.controlFill
    border.width: Theme.borderWidth
    border.color: Theme.controlBorder

    Accessible.role: Accessible.Grouping
    Keys.onPressed: event => {
        const direction = Keyboard.arrowStep(event);
        if (direction !== 0) {
            event.accepted = true;
            const index = root.currentIndex < 0 ? 0 : root.currentIndex + direction;
            root.pick(index, segments.itemAt(index), null);
        }
    }

    FontMetrics {
        id: segmentMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        font.bold: true
    }

    Rectangle {
        visible: root.currentIndex >= 0
        x: root.inset + Math.max(0, root.currentIndex) * root.segmentWidth
        y: root.inset
        width: root.segmentWidth
        height: root.height - root.inset * 2
        radius: Theme.borderRadius
        color: Theme.alpha(Theme.accent, Theme.tintStrong)
        border.width: Theme.borderWidth
        border.color: Theme.selectedBorder

        Behavior on x {
            NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing }
        }
    }

    Repeater {
        id: segments
        model: root.options

        delegate: Rectangle {
            id: segment

            required property var modelData
            required property int index
            readonly property bool selected: segment.index === root.currentIndex

            x: root.inset + segment.index * root.segmentWidth
            y: root.inset
            width: root.segmentWidth
            height: root.height - root.inset * 2
            radius: Theme.borderRadius
            color: segmentMouse.containsMouse && !segment.selected && root.enabled
                ? Theme.controlFill
                : "transparent"

            Accessible.role: Accessible.RadioButton
            Accessible.name: String(segment.modelData.label)
            Accessible.checked: segment.selected
            Accessible.onPressAction: if (root.enabled) root.pick(segment.index, segment, null)

            Label {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingTiny
                anchors.rightMargin: Theme.spacingTiny
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: String(segment.modelData.label)
                font.bold: true
                color: segment.selected ? Theme.text : Theme.subtext
                elide: Text.ElideRight

                Behavior on color {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }

            MouseArea {
                id: segmentMouse
                anchors.fill: parent
                enabled: root.enabled
                hoverEnabled: true
                cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.pick(segment.index, segment, segmentMouse)
            }
        }
    }

    FocusRing {}
}
