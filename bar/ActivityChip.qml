import QtQuick
import qs.services
import qs.theme
import "../services/TimerProvider.js" as TimerProvider

// Something running, in the bar: its icon in its tone, its name, and how long it has
// run, the icon spinning while it's busy. A click takes its first action (Finish,
// Stop), a right-click its second (Discard).
BarButton {
    id: root

    required property var activity

    readonly property var actions: root.activity.actions
    property double nowMs: Date.now()

    function act(index) {
        if (index < root.actions.length)
            ActivityService.requestAction(root.activity.provider, root.activity.id, root.actions[index].id);
    }

    iconName: root.activity.iconName
    iconColor: root.activity.tone !== "neutral" ? Theme.toneColor(root.activity.tone)
        : (root.pointerInside ? Theme.text : Theme.subtextBright)
    text: root.activity.label + "  "
        + TimerProvider.formatClock(Math.max(0, Math.floor((root.nowMs - root.activity.startedAt) / 1000)))
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
        running: root.visible
        onTriggered: root.nowMs = Date.now()
    }

    // It stops wherever it is; set the icon upright again.
    RotationAnimator {
        target: root.icon
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
        running: root.activity.state === "busy" && Theme.motion
        onRunningChanged: if (!running) root.icon.rotation = 0
    }
}
