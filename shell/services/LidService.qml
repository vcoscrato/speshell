pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The laptop's own display and its lid: with the lid closed and another display on, the
// laptop's display turns off, and it comes back as it was once the lid opens or the last
// other display goes. Waits while the Displays panel applies a change or has one to apply
// or keep. How the display was is kept in <dataDir>/lid.json, so a Speshell started with
// it off by the lid still brings it back.
Singleton {
    id: root

    // The laptop's display as it was before the closed lid turned it off, or null.
    property var parked: null
    property bool parkedRead: false

    function follow() {
        if (!HyprlandService.running || !root.parkedRead || DisplayService.busy || DisplayService.hasPending)
            return;
        const monitors = DisplayService.monitors;
        const internal = monitors.find(monitor => DisplayService.isInternal(monitor) && !monitor.disabled);
        const othersOn = monitors.some(monitor => !DisplayService.isInternal(monitor) && !monitor.disabled);
        if (SessionService.lidClosed && internal && othersOn && !root.parked) {
            root.park(internal);
            root.apply(Object.assign({}, internal, { disabled: true }));
        } else if (root.parked && (!SessionService.lidClosed || !othersOn)) {
            const parked = root.parked;
            root.park(null);
            root.apply(parked);
        }
    }

    function park(monitor) {
        root.parked = monitor;
        parkedFile.setText(JSON.stringify(monitor));
    }

    function apply(monitor) {
        HyprlandService.hyprctl(DisplayService.commandFor(monitor));
        DisplayService.queueRefresh();
    }

    function readParked(text) {
        try {
            const monitor = JSON.parse(text);
            root.parked = monitor && typeof monitor.name === "string" ? monitor : null;
        } catch (error) {
            root.parked = null;
        }
        root.parkedRead = true;
        root.follow();
    }

    Connections {
        target: SessionService

        function onLidClosedChanged() { DisplayService.refresh(); }
    }

    Connections {
        target: DisplayService

        function onMonitorsChanged() { Qt.callLater(root.follow); }
        // What waited for the panel follows once it's done.
        function onBusyChanged() { Qt.callLater(root.follow); }
        function onHasPendingChanged() { Qt.callLater(root.follow); }
    }

    FileView {
        id: parkedFile
        path: ConfigService.dataDir !== "" ? ConfigService.dataDir + "/lid.json" : ""
        atomicWrites: true
        printErrors: false
        onLoaded: root.readParked(parkedFile.text())
        onLoadFailed: root.readParked("null")
    }
}
