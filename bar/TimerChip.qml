import QtQuick
import qs.services
import qs.theme
import "../services/TimerProvider.js" as TimerProvider

// A timer in the bar: its name and the time left, or a prompt while it waits to be
// set. A click opens it; scrolling changes it by a minute, and a right-click pauses or
// resumes it.
BarButton {
    id: root

    required property var timer

    readonly property bool isSet: root.timer.isSet

    iconName: root.isSet && root.timer.paused ? "media-pause" : "timer"
    iconColor: Theme.accent
    text: !root.isSet ? (root.timer.name || "New timer")
        : (root.timer.name !== "" ? root.timer.name + "  " : "") + TimerProvider.formatClock(root.timer.remainingSeconds)
    tabularDigits: true
    label: !root.isSet ? "Set this timer"
        : (root.timer.name || "Timer") + " · " + (root.timer.paused ? "paused"
            : "ends at " + Qt.formatTime(new Date(root.timer.endsAtMs), "HH:mm"))
    onWheeled: delta => {
        if (delta)
            TimerService.add(root.timer, delta > 0 ? 60 : -60);
    }
    onRightClicked: TimerService.toggle(root.timer)
}
