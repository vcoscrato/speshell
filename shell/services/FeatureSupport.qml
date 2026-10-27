pragma Singleton
// Quickshell's type info leaves out BluetoothAdapter.
// qmllint disable unresolved-type

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.UPower

// What this machine has for Speshell: a battery, a backlight and a keyboard
// backlight, Bluetooth, radios, display control, and the commands Speshell runs; and
// the setup problems worth telling the user about.
Singleton {
    id: root
    property bool backlightProbeComplete: false
    property var backlightDevices: []
    // LEDs named *kbd_backlight, as dell::kbd_backlight.
    property var keyboardBacklightDevices: []

    // The commands Speshell may run: brightnessctl, power profiles, rfkill (airplane
    // mode), hyprsunset (night light), Tailscale, and the tools'.
    readonly property var wantedCommands: ["brightnessctl", "powerprofilesctl", "rfkill", "hyprsunset", "tailscale"]
        .concat(ToolsService.commands)
        .filter((command, index, all) => command !== "" && all.indexOf(command) === index)

    // Those found installed by the last probe, and the list it looked for.
    property var installedCommands: []

    property string probedCommands: ""

    // Whether the last probe covered every command wanted now.
    readonly property bool commandsKnown: root.probedCommands === root.wantedCommands.join(" ")

    readonly property bool brightnessHelperAvailable: root.hasCommand("brightnessctl")
    readonly property string configuredBacklightDevice: ConfigService.settings.backlight.device
    readonly property string backlightDeviceName: {
        if (root.configuredBacklightDevice !== ""
                && root.backlightDevices.indexOf(root.configuredBacklightDevice) !== -1)
            return root.configuredBacklightDevice;
        return root.backlightDevices.length > 0 ? root.backlightDevices[0] : "";
    }

    readonly property var battery: UPower.displayDevice
    readonly property bool supportsBattery: root.battery !== null
        && root.battery.ready
        && root.battery.isLaptopBattery
        && root.battery.isPresent

    readonly property bool supportsBrightness: root.backlightDevices.length > 0 && root.brightnessHelperAvailable
    readonly property string keyboardBacklightDeviceName: root.keyboardBacklightDevices[0] || ""
    readonly property bool supportsKeyboardBacklight: root.keyboardBacklightDeviceName !== "" && root.brightnessHelperAvailable
    readonly property bool supportsAirplaneMode: root.hasCommand("rfkill")
    readonly property bool supportsBluetooth: Bluetooth.defaultAdapter !== null
    // Displays are arranged through Hyprland.
    readonly property bool supportsDisplayControl: HyprlandService.running
    readonly property bool issuesReady: ConfigService.valid
        && root.backlightProbeComplete
        && root.commandsKnown

    readonly property var issues: {
        if (!root.issuesReady)
            return [];
        var result = [];
        var backlight = root.configuredBacklightDevice;
        if (backlight !== "" && root.backlightDevices.indexOf(backlight) === -1) {
            result.push({
                id: "backlight-device",
                title: "Backlight unavailable",
                detail: "The configured backlight device '" + backlight + "' was not found."
            });
        } else if (backlight !== "" && !root.brightnessHelperAvailable) {
            result.push({
                id: "backlight-helper",
                title: "Brightness controls unavailable",
                detail: "A backlight device is configured, but brightnessctl is not installed."
            });
        }
        return result;
    }

    function hasCommand(command) {
        return root.installedCommands.indexOf(command) >= 0;
    }

    // Looks for the wanted commands again, so one installed since shows up.
    function probeCommands() {
        if (commandProbe.running) {
            commandProbe.queued = true;
            return;
        }
        commandProbe.looking = root.wantedCommands.join(" ");
        commandProbe.command = ["sh", "-c", "for c; do command -v \"$c\" >/dev/null 2>&1 && echo \"$c\"; done", "sh"]
            .concat(root.wantedCommands);
        commandProbe.running = true;
    }

    onWantedCommandsChanged: root.probeCommands()

    Component.onCompleted: root.probeCommands()

    // The backlights, a line between them and the keyboard's.
    Process {
        running: true
        command: ["sh", "-c", "ls -1 /sys/class/backlight; echo --; ls -1 /sys/class/leds | grep 'kbd_backlight$'"]
        stdout: StdioCollector { id: backlightOutput }
        onExited: {
            const parts = backlightOutput.text.split(/^--$/m);
            const names = text => String(text || "").split("\n").map(line => line.trim()).filter(line => line !== "");
            root.backlightDevices = names(parts[0]);
            root.keyboardBacklightDevices = names(parts[1]);
            root.backlightProbeComplete = true;
        }
    }

    Process {
        id: commandProbe

        property string looking: ""
        property bool queued: false

        stdout: StdioCollector { id: commandOutput }
        onExited: {
            root.installedCommands = commandOutput.text.split("\n").filter(line => line !== "");
            root.probedCommands = commandProbe.looking;
            if (commandProbe.queued) {
                commandProbe.queued = false;
                root.probeCommands();
            }
        }
    }
}
