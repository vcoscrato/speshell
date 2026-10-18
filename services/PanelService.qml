pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import "../components/Icons.js" as Icons

// The bar's panels: which apply to this machine, the icon and few words that sum up
// each on its bar button, and requests to open one in the focused screen's bar, from
// the launcher or `speshell panel`.
Singleton {
    id: root

    // Every panel by id, with its label.
    readonly property var labels: ({
        audio: "Speaker",
        battery: "Battery",
        bluetooth: "Bluetooth",
        clipboard: "Clipboard",
        clock: "Clock",
        display: "Displays",
        media: "Now playing",
        microphone: "Microphone",
        network: "Network",
        notes: "Notes",
        notifications: "Notifications",
        power: "Power",
        settings: "Settings",
        tools: "Tools",
        weather: "Weather"
    })
    // Dropdowns open across the bars.
    property int openDropdowns: 0

    // The bar on the screen named `screen` opens `panel`, or closes it when `toggle`
    // and it is open.
    signal requested(string panel, string screen, bool toggle)
    // The bars close their dropdowns.
    signal dismissRequested()

    function has(panel) {
        return Object.prototype.hasOwnProperty.call(root.labels, panel);
    }

    function isSupported(panel) {
        if (panel === "battery")
            return FeatureSupport.supportsBattery;
        if (panel === "bluetooth")
            return FeatureSupport.supportsBluetooth;
        if (panel === "display")
            return FeatureSupport.supportsDisplayControl;
        if (panel === "media")
            return MediaService.player !== null;
        if (panel === "weather")
            return WeatherService.enabled;
        return root.has(panel);
    }

    // The icon of a panel's bar button, showing its state.
    function icon(panel) {
        if (panel === "audio") {
            if (AudioService.outputMuted)
                return "audio-output-muted";
            return AudioService.outputVolumePercent <= 35 ? "audio-output-low" : "audio-output-high";
        }
        if (panel === "microphone")
            return AudioService.inputMuted ? "audio-input-muted" : "audio-input";
        if (panel === "display")
            return BrightnessService.available ? "brightness" : "display";
        if (panel === "network") {
            if (VpnService.active)
                return "vpn";
            if (NetworkService.wiredDevice !== null)
                return "network-wired";
            const wifi = NetworkService.connectedWifi;
            return wifi !== null ? NetworkService.signalIcon(NetworkService.signalPercent(wifi.signalStrength)) : "wifi-off";
        }
        if (panel === "bluetooth")
            return BluetoothService.enabled ? "bluetooth" : "bluetooth-off";
        if (panel === "battery") {
            const battery = UPower.displayDevice;
            if (!battery || !battery.ready)
                return "battery";
            return Icons.batteryFor(battery.percentage * 100, battery.state === UPowerDeviceState.Charging
                || battery.state === UPowerDeviceState.PendingCharge);
        }
        if (panel === "notifications")
            return NotificationService.dndEnabled ? "bell-off" : "bell";
        if (panel === "tools")
            return ToolsService.statusIcon;
        if (panel === "weather")
            return WeatherService.ready ? WeatherService.current.icon : "weather-cloudy";
        return ({ clipboard: "clipboard", notes: "notes", settings: "config", power: "power" })[panel] || "missing";
    }

    // A panel's state in a few words, for its bar button's label.
    function status(panel) {
        if (panel === "audio")
            return (AudioService.outputDeviceLabel || "Volume") + ": " + AudioService.outputVolumePercent + "%";
        if (panel === "microphone")
            return (AudioService.inputDeviceLabel || "Mic") + ": " + AudioService.inputVolumePercent + "%";
        if (panel === "display" && BrightnessService.available)
            return "Brightness: " + BrightnessService.percent + "%";
        if (panel === "network") {
            if (NetworkService.wiredDevice)
                return "Ethernet";
            const wifi = NetworkService.connectedWifi;
            if (wifi)
                return "Wi-Fi: " + wifi.name;
            return NetworkService.wifiOn ? "Disconnected" : "Wi-Fi off";
        }
        if (panel === "bluetooth")
            return BluetoothService.enabled ? "Bluetooth on" : "Bluetooth off";
        if (panel === "battery") {
            const battery = UPower.displayDevice;
            return battery && battery.ready ? "Battery: " + Math.round(battery.percentage * 100) + "%" : "Battery";
        }
        if (panel === "clipboard") {
            const count = ClipboardService.history.length;
            return count > 0 ? "Clipboard (" + count + " item" + (count === 1 ? "" : "s") + ")" : "Clipboard";
        }
        if (panel === "notifications") {
            const count = NotificationService.notificationHistory.length;
            if (NotificationService.dndEnabled)
                return "Do not disturb";
            return count > 0 ? count + " notification" + (count === 1 ? "" : "s") : "Notifications";
        }
        if (panel === "tools")
            return ToolsService.statusText;
        if (panel === "weather")
            return WeatherService.summary || "Weather";
        return root.labels[panel] || "";
    }

    function request(panel, toggle) {
        if (!root.isSupported(panel))
            return false;
        const screen = HyprlandService.focusedScreen();
        root.requested(panel, screen ? screen.name : "", toggle);
        return true;
    }

    // Opens `panel` in the focused screen's bar. Returns whether it is a panel this
    // machine has.
    function open(panel) {
        return root.request(panel, false);
    }

    function toggle(panel) {
        return root.request(panel, true);
    }

    // Closes every dropdown. Returns whether any was open.
    function dismiss() {
        const shown = root.openDropdowns > 0;
        root.dismissRequested();
        return shown;
    }
}
