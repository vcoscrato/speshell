import QtQuick
import QtQuick.Controls as Controls
import qs.services
import "Keyboard.js" as Keyboard

// A themed slider: the theme's knob, and the effects that follow the hand on it. The
// wheel and the arrow keys step it by `stepSize` through `stepped`, leaving `value` to
// whoever binds it.
Controls.Slider {
    id: root

    property color progressColor: Theme.accent
    property real trackHeight: Theme.spacingSmall
    property real handleSize: Theme.iconSizeMedium
    // Scrolled or keyed a step, to `nextValue`.
    signal stepped(real nextValue)

    // Where the knob was when last reported to the theme effects.
    property real reportedKnobX: 0

    function reportKnob(dx) {
        if (dx !== 0)
            EffectsService.knobMoved(root.handle, dx);
    }

    function step(direction) {
        const next = Math.max(root.from, Math.min(root.to, root.value + direction * (root.stepSize > 0 ? root.stepSize : 5)));
        if (next === root.value)
            return;
        root.reportKnob((next - root.value) / (root.to - root.from) * (root.availableWidth - root.handle.width));
        root.stepped(next);
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
    focusPolicy: Qt.TabFocus

    // Before the slider's own handling, which would set `value` and break its binding.
    Keys.onPressed: event => {
        const direction = Keyboard.arrowStep(event);
        if (direction !== 0) {
            event.accepted = true;
            root.step(direction);
        }
    }

    MouseArea {
        id: hoverMouse
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPositionChanged: mouse => EffectsService.pointKnob(knob.item, hoverMouse, mouse)
    }

    WheelSteps {
        onStepped: direction => root.step(direction)
    }

    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        height: root.trackHeight
        radius: height / 2
        color: Theme.trackFill
        clip: true

        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: parent.radius
            color: root.progressColor

            Behavior on width {
                NumberAnimation { duration: Theme.animDurationFast; easing.type: Theme.animEasing }
            }

            Behavior on color {
                ColorAnimation { duration: Theme.animDuration }
            }
        }
    }

    handle: Rectangle {
        // A touch larger under the hand.
        readonly property real size: sliderMouse.containsMouse || root.pressed ? root.handleSize + Theme.spacingMicro : root.handleSize

        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: size
        height: size
        radius: height / 2
        color: knob.status === Loader.Ready ? "transparent" : Theme.bg
        border.width: knob.status === Loader.Ready ? 0 : Theme.outlineWidth
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
            onPositionChanged: mouse => EffectsService.pointKnob(knob.item, sliderMouse, mouse)
        }

        FocusRing {
            control: root
            anchors.margins: -Theme.outlineWidth
            radius: height / 2
        }
    }
}
