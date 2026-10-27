import QtQuick
import qs.services
import "../components/Format.js" as Format

// A timer in the bar: its name and the time left, or a prompt while it waits to be
// set. A click opens it; scrolling changes it by a minute, and a right-click pauses or
// resumes it.
BarButton {
    id: root

    required property var timer

    readonly property bool isSet: root.timer.isSet
    // In a crowded bar: the time left alone.
    property bool compact: false

    iconName: root.isSet && root.timer.paused ? "media-pause" : "timer"
    iconColor: Theme.accent
    text: !root.isSet ? (root.timer.name || "New timer")
        : (root.timer.name !== "" && !root.compact ? root.timer.name + "  " : "") + Format.clock(root.timer.remainingSeconds)
    tabularDigits: true
    label: !root.isSet ? "Set this timer"
        : (root.timer.name || "Timer") + " · " + (root.timer.paused ? "paused"
            : "ends at " + Format.time(new Date(root.timer.endsAtMs)))
    onWheeled: delta => {
        if (delta)
            TimerService.add(root.timer, delta > 0 ? 60 : -60);
    }
    onRightClicked: TimerService.toggle(root.timer)
}
