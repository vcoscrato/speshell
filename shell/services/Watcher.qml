import QtQuick
import Quickshell.Io

// A Process that follows something for as long as `watching` holds: set that, never
// `running`. When it stops, or fails to start, it starts again after a second, twice
// as long each time it stops within a minute of starting, up to a minute; a run that
// lasted a minute starts the count over.
Process {
    id: root

    property bool watching: false
    property int failures: 0
    property double startedAt: 0

    readonly property Timer restartTimer: Timer {
        onTriggered: root.follow()
    }

    function follow() {
        root.restartTimer.stop();
        // From the attempt, so one that fails to start counts as stopping at once.
        if (root.watching && !root.running)
            root.startedAt = Date.now();
        root.running = root.watching;
    }

    onWatchingChanged: {
        root.failures = 0;
        root.follow();
    }
    Component.onCompleted: root.follow()
    onRunningChanged: {
        if (root.running || !root.watching)
            return;
        root.failures = Date.now() - root.startedAt >= 60000 ? 0 : root.failures + 1;
        root.restartTimer.interval = Math.min(60000, 1000 * Math.pow(2, Math.max(0, root.failures - 1)));
        root.restartTimer.restart();
    }
}
