import QtQuick
import qs.services
import "Keyboard.js" as Keyboard

// An on/off switch with the theme's knob. It shows the requested state at once and
// falls back if the change doesn't happen. Space or Enter flips it from the keyboard.
Rectangle {
    id: root

    property bool checked: false
    property string tooltipText: ""

    signal toggled(bool newState)

    // What a flip asked for, shown until `checked` agrees or the backend has had a few
    // seconds: turning a radio on can take a while to report.
    property bool pending: false
    property bool requested: false
    readonly property bool on: root.pending ? root.requested : root.checked

    // The thumb, at an inset as wide all round, with as much again to travel.
    readonly property int thumbSize: Theme.iconSizeSmall
    readonly property real inset: (root.height - root.thumbSize) / 2

    onCheckedChanged: if (root.checked === root.requested) root.pending = false

    implicitHeight: Theme.controlHeightSmall - Theme.spacingTiny
    implicitWidth: root.implicitHeight + root.thumbSize + Theme.spacingMicro
    radius: height / 2
    opacity: enabled ? 1.0 : Theme.disabledOpacity
    activeFocusOnTab: true

    color: root.on
        ? Theme.accent
        : Theme.trackFill
    border.width: Theme.borderWidth
    border.color: root.on
        ? Theme.accent
        : Theme.controlBorder

    Behavior on color {
        ColorAnimation { duration: Theme.animDuration }
    }

    Behavior on border.color {
        ColorAnimation { duration: Theme.animDuration }
    }

    Accessible.role: Accessible.CheckBox
    Accessible.name: root.tooltipText
    Accessible.checked: root.on
    Accessible.onPressAction: {
        if (root.enabled)
            root.flip();
    }
    Keys.onPressed: event => {
        if (Keyboard.presses(event)) {
            event.accepted = true;
            root.flip();
        }
    }

    function flip() {
        const next = !root.on;
        root.requested = next;
        root.pending = next !== root.checked;
        if (root.pending)
            pendingTimer.restart();
        EffectsService.switched(root, next);
        root.toggled(next);
    }

    Timer {
        id: pendingTimer
        interval: 4000
        onTriggered: root.pending = false
    }

    Rectangle {
        id: thumb
        width: switchMouse.pressed ? root.thumbSize + Theme.spacingMicro : root.thumbSize
        height: root.thumbSize
        radius: height / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.on ? root.width - width - root.inset : root.inset

        color: knob.status === Loader.Ready ? "transparent"
            : root.on ? Theme.bg : Theme.subtext

        Behavior on x {
            NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing }
        }

        Behavior on width {
            NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing }
        }

        Behavior on color {
            ColorAnimation { duration: Theme.animDuration }
        }

        // The theme effects' knob, when they have one.
        Loader {
            id: knob
            anchors.centerIn: parent
            // EffectClock runs at this speed and frame rate.
            property real timeScale: 1
            property int frameRate: EffectsService.frameRate
            width: parent.height
            height: parent.height
            sourceComponent: EffectsService.knob
            onLoaded: EffectsService.placeKnobOnSwitch(item, () => Qt.rect(-thumb.x - knob.x, -thumb.y - knob.y, root.width, root.height))
        }

        Binding { target: knob.item; property: "theme"; value: Theme }
        Binding { target: knob.item; property: "pressed"; value: switchMouse.pressed }
        Binding { target: knob.item; property: "hovered"; value: switchMouse.containsMouse }
        Binding { target: knob.item; property: "checked"; value: root.on }
        Binding { target: knob.item; property: "travel"; value: thumb.x }
    }

    MouseArea {
        id: switchMouse
        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.flip()
        onPositionChanged: mouse => EffectsService.pointKnob(knob.item, switchMouse, mouse)
    }

    Tooltip {
        visible: root.tooltipText !== "" && (switchMouse.containsMouse || root.activeFocus)
        text: root.tooltipText
    }

    FocusRing {
        radius: height / 2
    }
}
