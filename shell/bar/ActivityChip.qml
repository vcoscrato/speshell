import QtQuick
import qs.services
import "../components/Format.js" as Format

// Something running, in the bar: its icon in its tone, its name, and how long it has
// run, the icon spinning while it's busy and ringing, on a glowing fill, while it waits
// on you. A click takes its first action (Finish, Stop), a right-click its second
// (Discard).
BarButton {
    id: root

    required property var activity

    readonly property var actions: root.activity.actions
    // In a crowded bar: the running time alone.
    property bool compact: false
    property double nowMs: Date.now()
    readonly property bool ringing: root.activity.attention && root.visible
    property real glow: 0

    function act(index) {
        if (index < root.actions.length)
            ActivityService.requestAction(root.activity.provider, root.activity.id, root.actions[index].id);
    }

    iconName: root.activity.iconName
    iconColor: root.activity.tone !== "neutral" ? Theme.toneColor(root.activity.tone)
        : (root.pointerInside ? Theme.text : Theme.subtextBright)
    text: !root.activity.timed ? (root.compact ? "" : root.activity.label)
        : (root.compact ? "" : root.activity.label + "  ") + Format.clock((root.nowMs - root.activity.startedAt) / 1000)
    restFill: root.ringing ? Theme.alpha(Theme.toneColor(root.activity.tone), root.glow) : "transparent"
    tabularDigits: true
    label: [root.activity.label, root.activity.detail,
        root.actions.length === 0 ? ""
            : "Click to " + root.actions[0].label.toLowerCase()
                + (root.actions.length > 1 ? ", right-click to " + root.actions[1].label.toLowerCase() : "")]
        .filter(part => part !== "").join(" · ")
    onClicked: root.act(0)
    onRightClicked: root.act(1)

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.activity.timed
        onTriggered: root.nowMs = Date.now()
    }

    // A bell's swing from its top, then a rest, while the fill breathes.
    SequentialAnimation {
        running: root.ringing
        loops: Animation.Infinite
        onStopped: root.icon.rotation = 0

        RotationAnimation { target: root.icon; to: 18; duration: 70; direction: RotationAnimation.Shortest }
        RotationAnimation { target: root.icon; to: -16; duration: 110; direction: RotationAnimation.Shortest }
        RotationAnimation { target: root.icon; to: 12; duration: 100; direction: RotationAnimation.Shortest }
        RotationAnimation { target: root.icon; to: -8; duration: 90; direction: RotationAnimation.Shortest }
        RotationAnimation { target: root.icon; to: 4; duration: 80; direction: RotationAnimation.Shortest }
        RotationAnimation { target: root.icon; to: 0; duration: 70; direction: RotationAnimation.Shortest }
        PauseAnimation { duration: 1300 }
    }

    SequentialAnimation {
        running: root.ringing
        loops: Animation.Infinite
        onStopped: root.glow = 0

        NumberAnimation { target: root; property: "glow"; from: 0.1; to: 0.28; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "glow"; from: 0.28; to: 0.1; duration: 900; easing.type: Easing.InOutSine }
    }

    // A bell swings from its top; a spinner turns about its middle.
    Binding {
        target: root.icon
        property: "transformOrigin"
        value: root.ringing ? Item.Top : Item.Center
    }

    Binding {
        target: root.icon
        property: "spinning"
        value: root.activity.state === "busy"
    }
}
