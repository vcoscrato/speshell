pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The night light, by [NightLight]: warmer colors on every display while hyprsunset,
// which Speshell runs, is up. Hyprland only.
Singleton {
    id: root

    readonly property var settings: ConfigService.settings.nightLight
    readonly property bool available: HyprlandService.running && FeatureSupport.hasCommand("hyprsunset")
    readonly property bool enabled: root.settings.enabled
    readonly property int temperature: root.settings.temperature
    readonly property bool active: sunset.running
    // Why hyprsunset stopped, as when another one already runs; empty while it's fine.
    property string errorText: ""

    function setEnabled(on) {
        root.errorText = "";
        ConfigService.setProperty("NightLight", "enabled", on ? "true" : "false");
    }

    // From a keybinding: shown in the OSD.
    function setFromKey(on) {
        if (!root.available)
            return;
        root.setEnabled(on);
        OsdService.show("night-light", on ? "Night light on" : "Night light off", "", -1);
    }

    Process {
        id: sunset
        running: root.available && root.enabled
        command: ["hyprsunset", "--temperature", String(root.temperature)]
        stderr: StdioCollector { id: sunsetError }
        onExited: exitCode => {
            if (root.enabled && exitCode !== 0)
                root.errorText = (sunsetError.text.trim().split("\n").pop() || "hyprsunset exited.").trim();
        }
    }

    // A running hyprsunset takes a new temperature over Hyprland's socket.
    onTemperatureChanged: {
        if (sunset.running)
            Quickshell.execDetached(["hyprctl", "hyprsunset", "temperature", String(root.temperature)]);
    }
}
