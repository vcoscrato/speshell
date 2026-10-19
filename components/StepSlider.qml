pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.theme

// A small slider over evenly graded values, a tick under each, captioned with its label
// and value. It commits a value when let go, per wheel notch, or per arrow key, not on
// every step of a drag.
Item {
    id: root

    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 1
    property real stepSize: 0.25
    // Turns a value into its caption.
    property var format: function(value) { return String(value); }

    signal committed(real value)

    readonly property int stops: Math.round((root.to - root.from) / root.stepSize) + 1

    implicitWidth: 96
    implicitHeight: caption.height + slider.height

    function snap(value) {
        return Math.round((value - root.from) / root.stepSize) * root.stepSize + root.from;
    }

    Item {
        id: caption
        width: parent.width
        height: valueText.implicitHeight

        Label {
            role: "caption"
            width: parent.width - valueText.implicitWidth - Theme.spacingTiny
            text: root.label
            elide: Text.ElideRight
        }

        Label {
            id: valueText
            role: "caption"
            anchors.right: parent.right
            text: root.format(root.snap(slider.value))
            color: Theme.text
        }
    }

    StyledSlider {
        id: slider

        y: caption.height
        width: parent.width
        height: Theme.controlHeightSmall
        leftPadding: 0
        rightPadding: 0
        from: root.from
        to: root.to
        stepSize: root.stepSize
        snapMode: Controls.Slider.SnapAlways
        value: root.value
        Accessible.name: root.label

        onPressedChanged: {
            if (!slider.pressed && root.snap(slider.value) !== root.value)
                root.committed(root.snap(slider.value));
        }
        onMoved: {
            if (!slider.pressed)
                root.committed(root.snap(slider.value));
        }
        onWheelAdjusted: function(nextValue) { root.committed(root.snap(nextValue)); }
    }

    // A tick under each stop, where the knob's center rests on it.
    Repeater {
        model: root.stops

        Rectangle {
            id: tick
            required property int index
            readonly property real share: root.stops > 1 ? tick.index / (root.stops - 1) : 0
            readonly property real knob: slider.handleSize

            x: slider.x + slider.leftPadding + tick.knob / 2 + tick.share * (slider.availableWidth - tick.knob) - tick.width / 2
            y: slider.y + slider.height / 2 + slider.trackHeight / 2 + 2
            width: Theme.borderWidth
            height: 3
            color: tick.share <= slider.visualPosition ? Theme.alpha(Theme.accent, Theme.tintOutlineStrong)
                : Theme.alpha(Theme.overlay, Theme.tintOutlineStrong)
        }
    }
}
