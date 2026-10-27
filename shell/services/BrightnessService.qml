pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Owns the configured backlight and the keyboard's: reads sysfs and writes through
// brightnessctl. Changes made outside Speshell, as with brightness keys, show the OSD;
// idling dims both until input returns, and unplugging lowers the screen to
// [Backlight] batteryPercent until plugged in.
Singleton {
    id: root

    readonly property bool available: FeatureSupport.supportsBrightness
    readonly property string device: FeatureSupport.backlightDeviceName
    readonly property int minimumPercent: 5
    property int percent: root.minimumPercent

    property int pendingPercent: root.minimumPercent
    property bool writeQueued: false

    // The keyboard backlight, in the firmware's steps: 0 is off.
    readonly property bool keyboardAvailable: FeatureSupport.supportsKeyboardBacklight
    readonly property string keyboardDevice: FeatureSupport.keyboardBacklightDeviceName
    property int keyboardLevel: 0
    property int keyboardMax: 0
    property bool keyboardWriteQueued: false
    readonly property int keyboardPercent: root.keyboardMax > 0 ? Math.round(root.keyboardLevel * 100 / root.keyboardMax) : 0

    // While idle: the levels to return to, or -1.
    property bool dimmed: false
    property int undimPercent: -1
    property int undimKeyboardLevel: -1

    // On battery: the most brightness, 0 for no limit, and the level to return to once
    // plugged in, or -1.
    readonly property int batteryPercent: ConfigService.settings.backlight.batteryPercent
    property int pluggedPercent: -1

    // Speshell's own writes don't show the OSD; the values it last saw, so it only
    // shows for real changes.
    property double osdSuppressedUntil: 0
    property int osdPercent: -1
    property int osdKeyboardLevel: -1

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

    // From a keybinding: a step, shown in the OSD.
    function stepFromKey(direction) {
        if (!root.available)
            return;
        root.stepPercent(direction);
        root.commit();
        OsdService.showPercent("brightness", "Brightness", root.percent);
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
        root.osdSuppressedUntil = Date.now() + 1000;
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
        if (root.osdPercent >= 0 && pct !== root.osdPercent && Date.now() >= root.osdSuppressedUntil)
            OsdService.showPercent("brightness", "Brightness", pct);
        root.osdPercent = pct;
    }

    function setKeyboardLevel(level) {
        if (!root.keyboardAvailable || root.keyboardMax <= 0)
            return;
        root.keyboardLevel = Math.max(0, Math.min(root.keyboardMax, Math.round(Number(level) || 0)));
        root.osdSuppressedUntil = Date.now() + 1000;
        if (keyboardWriteProc.running) {
            root.keyboardWriteQueued = true;
            return;
        }
        root.keyboardWriteQueued = false;
        keyboardWriteProc.command = ["brightnessctl", "-d", root.keyboardDevice, "set", String(root.keyboardLevel)];
        keyboardWriteProc.running = true;
    }

    // From a keybinding: the next step, wrapping to off, shown in the OSD.
    function cycleKeyboard() {
        if (!root.keyboardAvailable || root.keyboardMax <= 0)
            return;
        root.setKeyboardLevel(root.keyboardLevel >= root.keyboardMax ? 0 : root.keyboardLevel + 1);
        root.showKeyboardOsd();
    }

    function showKeyboardOsd() {
        OsdService.show("keyboard", "Keyboard backlight", root.keyboardLevel === 0 ? "Off" : root.keyboardPercent + "%",
            root.keyboardPercent / 100);
    }

    function updateKeyboardFromFiles() {
        if (!root.keyboardAvailable || !keyboardFile.loaded || !keyboardMaxFile.loaded)
            return;
        const level = parseInt((keyboardFile.text() || "").trim(), 10);
        const max = parseInt((keyboardMaxFile.text() || "").trim(), 10);
        if (isNaN(level) || isNaN(max) || max <= 0)
            return;
        root.keyboardMax = max;
        if (!keyboardWriteProc.running)
            root.keyboardLevel = Math.max(0, Math.min(max, level));
        if (root.osdKeyboardLevel >= 0 && root.keyboardLevel !== root.osdKeyboardLevel
                && Date.now() >= root.osdSuppressedUntil)
            root.showKeyboardOsd();
        root.osdKeyboardLevel = root.keyboardLevel;
    }

    // Dims the screen to a quarter and turns the keyboard backlight off, until undim().
    function dim() {
        if (root.dimmed)
            return;
        root.dimmed = true;
        if (root.available && root.percent > root.minimumPercent) {
            root.undimPercent = root.percent;
            root.setPercent(root.percent / 4);
            root.commit();
        }
        if (root.keyboardAvailable && root.keyboardLevel > 0) {
            root.undimKeyboardLevel = root.keyboardLevel;
            root.setKeyboardLevel(0);
        }
    }

    function undim() {
        if (!root.dimmed)
            return;
        root.dimmed = false;
        if (root.undimPercent >= 0) {
            root.setPercent(root.undimPercent);
            root.commit();
        }
        if (root.undimKeyboardLevel >= 0)
            root.setKeyboardLevel(root.undimKeyboardLevel);
        root.undimPercent = -1;
        root.undimKeyboardLevel = -1;
    }

    // While dimmed, it moves the level that undimming returns to.
    function followPowerSource() {
        if (!root.available || !brightnessFile.loaded || root.batteryPercent === 0) {
            root.pluggedPercent = -1;
            return;
        }
        const dimmedLevel = root.dimmed && root.undimPercent >= 0;
        const current = dimmedLevel ? root.undimPercent : root.percent;
        let next;
        if (UPower.onBattery) {
            const limit = root.clampPercent(root.batteryPercent);
            if (current <= limit)
                return;
            root.pluggedPercent = current;
            next = limit;
        } else {
            if (root.pluggedPercent < 0)
                return;
            // Turned up on battery past where it was: left as it is.
            next = Math.max(current, root.pluggedPercent);
            root.pluggedPercent = -1;
        }
        if (dimmedLevel) {
            root.undimPercent = next;
        } else {
            root.setPercent(next);
            root.commit();
        }
    }

    // Unplugging and plugging in, on a laptop.
    Connections {
        target: UPower

        function onOnBatteryChanged() {
            if (FeatureSupport.supportsBattery)
                root.followPowerSource();
        }
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

    FileView {
        id: keyboardFile
        path: root.keyboardDevice !== "" ? "/sys/class/leds/" + root.keyboardDevice + "/brightness" : ""
        printErrors: false
        watchChanges: root.keyboardAvailable
        onLoaded: root.updateKeyboardFromFiles()
        onTextChanged: root.updateKeyboardFromFiles()
        onFileChanged: reload()
    }

    FileView {
        id: keyboardMaxFile
        path: root.keyboardDevice !== "" ? "/sys/class/leds/" + root.keyboardDevice + "/max_brightness" : ""
        printErrors: false
        onLoaded: root.updateKeyboardFromFiles()
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

    Process {
        id: keyboardWriteProc
        running: false
        onExited: {
            if (root.keyboardWriteQueued)
                root.setKeyboardLevel(root.keyboardLevel);
            else
                keyboardFile.reload();
        }
    }

    Timer {
        id: writeDebounce
        interval: 120
        repeat: false
        onTriggered: root.write()
    }
}
