pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Owns the configured backlight: reads sysfs and writes through brightnessctl.
Singleton {
    id: root

    readonly property bool available: FeatureSupport.supportsBrightness
    readonly property string device: FeatureSupport.backlightDeviceName
    readonly property int minimumPercent: 5
    property int percent: root.minimumPercent

    property int pendingPercent: root.minimumPercent
    property bool writeQueued: false

    function clampPercent(value) {
        return Math.max(root.minimumPercent, Math.min(100, Math.round(Number(value) || 0)));
    }

    function refresh() {
        if (!root.available)
            return;
        brightnessFile.reload();
        maxBrightnessFile.reload();
    }

    // Updates the displayed value immediately and writes after a short debounce.
    function setPercent(value) {
        if (!root.available)
            return;
        root.pendingPercent = root.clampPercent(value);
        root.percent = root.pendingPercent;
        writeDebounce.restart();
    }

    // Moves brightness by one wheel step; direction is positive or negative.
    function stepPercent(direction) {
        if (direction)
            root.setPercent(root.percent + (direction > 0 ? 5 : -5));
    }

    // Flushes a debounced write, e.g. when a slider is released.
    function commit() {
        if (!writeDebounce.running)
            return;
        writeDebounce.stop();
        root.write();
    }

    function write() {
        if (!root.available)
            return;
        if (writeProc.running) {
            root.writeQueued = true;
            return;
        }
        root.writeQueued = false;
        writeProc.command = ["brightnessctl", "-d", root.device, "set", root.pendingPercent + "%"];
        writeProc.running = true;
    }

    function updateFromFiles() {
        if (!root.available || !brightnessFile.loaded || !maxBrightnessFile.loaded)
            return;

        var current = parseInt((brightnessFile.text() || "").trim(), 10);
        var max = parseInt((maxBrightnessFile.text() || "").trim(), 10);
        if (isNaN(current) || isNaN(max) || max <= 0)
            return;

        var pct = Math.max(0, Math.min(100, Math.round((current / max) * 100)));
        root.percent = pct;
        if (!writeProc.running && !writeDebounce.running)
            root.pendingPercent = pct;
    }

    FileView {
        id: brightnessFile
        path: root.device !== "" ? "/sys/class/backlight/" + root.device + "/brightness" : ""
        printErrors: false
        watchChanges: root.available
        onLoaded: root.updateFromFiles()
        onTextChanged: root.updateFromFiles()
        onFileChanged: reload()
    }

    FileView {
        id: maxBrightnessFile
        path: root.device !== "" ? "/sys/class/backlight/" + root.device + "/max_brightness" : ""
        printErrors: false
        watchChanges: root.available
        onLoaded: root.updateFromFiles()
        onTextChanged: root.updateFromFiles()
        onFileChanged: reload()
    }

    Process {
        id: writeProc
        running: false
        onExited: {
            if (root.writeQueued) {
                root.write();
                return;
            }
            root.refresh();
        }
    }

    Timer {
        id: writeDebounce
        interval: 120
        repeat: false
        onTriggered: root.write()
    }
}
