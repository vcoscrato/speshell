pragma Singleton
// Quickshell's type info leaves out BluetoothAdapter.
// qmllint disable unresolved-type

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.UPower

Singleton {
    id: root

    property bool brightnessHelperAvailable: false
    property bool backlightProbeComplete: false
    property bool helperProbeComplete: false
    property var backlightDevices: []
    property string configuredBacklightDevice: ""
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
    readonly property bool supportsBluetooth: Bluetooth.defaultAdapter !== null
    // Displays are arranged through Hyprland.
    readonly property bool supportsDisplayControl: HyprlandService.running
    readonly property bool issuesReady: ConfigService.valid
        && root.backlightProbeComplete
        && root.helperProbeComplete
        && !PowerService.lockerChecking
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
        var locker = String((PowerService.lockCommand || [])[0] || "");
        if (locker !== "" && !PowerService.lockerAvailable) {
            result.push({
                id: "power-locker",
                title: "Screen locking unavailable",
                detail: "The configured locker '" + locker + "' could not be found."
            });
        }
        return result;
    }

    Process {
        running: true
        command: ["ls", "-1", "/sys/class/backlight"]
        stdout: StdioCollector { id: backlightOutput }
        onExited: {
            root.backlightDevices = backlightOutput.text.split("\n")
                .map(function(line) { return line.trim(); })
                .filter(function(line) { return line !== ""; });
            root.backlightProbeComplete = true;
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v brightnessctl"]
        onExited: exitCode => {
            root.brightnessHelperAvailable = exitCode === 0;
            root.helperProbeComplete = true;
        }
    }
}
