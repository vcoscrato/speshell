import QtQuick
import qs.services

// A level to set: what leads it (a mute button, a label), a slider, and the level as
// text, as the speaker's volume or the screen's brightness show in their panels and in
// the OSD.
Item {
    id: root

    default property alias leading: leadingRow.data
    property alias from: slider.from
    property alias to: slider.to
    property alias stepSize: slider.stepSize
    property alias progressColor: slider.progressColor
    property real value: 0
    property string valueText: ""
    property bool adjustable: true

    // Dragged or wheeled to `nextValue`.
    signal adjusted(real nextValue)
    // Let go after a drag.
    signal released()

    width: parent ? parent.width : implicitWidth
    implicitHeight: Theme.controlHeight

    Row {
        id: leadingRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
    }

    StyledSlider {
        id: slider
        anchors.left: leadingRow.right
        anchors.leftMargin: leadingRow.width > 0 ? Theme.spacingSmall : 0
        anchors.right: valueLabel.left
        anchors.rightMargin: Theme.spacingSmall
        anchors.verticalCenter: parent.verticalCenter
        value: root.value
        enabled: root.adjustable
        onMoved: root.adjusted(value)
        onWheelAdjusted: nextValue => root.adjusted(nextValue)
        onPressedChanged: if (!pressed) root.released()
    }

    // Wide enough for "Muted", so the slider keeps its length.
    Label {
        id: valueLabel
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(40 * Math.max(1, Theme.textScale))
        horizontalAlignment: Text.AlignRight
        text: root.valueText
        color: Theme.subtext
        font.features: { "tnum": 1 }
    }
}
