import QtQuick
import QtQuick.Controls as Controls
import qs.services
import qs.theme

// A themed slider: the theme's knob, and the effects that follow the hand on it.
Controls.Slider {
    id: root

    property color progressColor: Theme.accent
    property real trackHeight: 8
    property real handleSize: 18
    signal wheelAdjusted(real nextValue)

    // Where the knob was when last reported to the theme effects.
    property real reportedKnobX: 0

    function reportKnob(dx) {
        if (dx !== 0)
            EffectsService.knobMoved(root.handle, dx);
    }

    onPressedChanged: {
        root.reportedKnobX = root.handle.x;
        if (!root.pressed)
            EffectsService.knobReleased(root.handle);
    }
    onMoved: {
        root.reportKnob(root.handle.x - root.reportedKnobX);
        root.reportedKnobX = root.handle.x;
    }

    from: 0
    to: 100
    stepSize: 1
    height: Theme.controlHeight
    focusPolicy: Qt.ClickFocus

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onWheel: function(wheel) {
            if (wheel.angleDelta.y === 0)
                return;
            var step = root.stepSize > 0 ? root.stepSize : 5;
            var delta = wheel.angleDelta.y > 0 ? step : -step;
            var newVal = Math.max(root.from, Math.min(root.to, root.value + delta));
            if (newVal !== root.value) {
                root.reportKnob((newVal - root.value) / (root.to - root.from) * (root.availableWidth - root.handle.width));
                root.wheelAdjusted(newVal);
            }
            wheel.accepted = true;
        }
    }

    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        height: root.trackHeight
        radius: height / 2
        color: Theme.alpha(Theme.surface2, 0.5)
        clip: true

        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: root.progressColor

            Behavior on width {
                NumberAnimation { duration: Theme.motion ? 60 : 0; easing.type: Theme.animEasing }
            }

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }
    }

    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: sliderMouse.containsMouse || root.pressed ? 20 : root.handleSize
        height: sliderMouse.containsMouse || root.pressed ? 20 : root.handleSize
        radius: height / 2
        color: knob.status === Loader.Ready ? "transparent" : Theme.bg
        border.width: knob.status === Loader.Ready ? 0 : 2
        border.color: Theme.accent

        Behavior on width {
            NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing }
        }

        Behavior on height {
            NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing }
        }

        // The theme effects' knob, when they have one.
        Loader {
            id: knob
            anchors.fill: parent
            // EffectClock runs at this speed and frame rate.
            property real timeScale: 1
            property int frameRate: EffectsService.frameRate
            sourceComponent: EffectsService.knob
        }

        Binding { target: knob.item; property: "theme"; value: Theme }
        Binding { target: knob.item; property: "pressed"; value: root.pressed }
        Binding { target: knob.item; property: "hovered"; value: sliderMouse.containsMouse || root.hovered }
        Binding { target: knob.item; property: "checked"; value: true }
        Binding { target: knob.item; property: "travel"; value: root.handle ? root.handle.x : 0 }

        MouseArea {
            id: sliderMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
    }
}
