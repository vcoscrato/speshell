pragma Singleton
import QtQuick
import Quickshell

// The bar's panels: which apply to this machine, the icon and few words that sum up
// each on its bar button, and requests to open one in the focused screen's bar, from
// the launcher or `speshell panel`.
Singleton {
    id: root

    // Every panel by id: its name and the icon of its header, which a Card with its id
    // shows, and of its bar button while its state doesn't change it.
    readonly property var panels: ({
        audio: { label: "Speaker", icon: "audio-output" },
        battery: { label: "Battery", icon: "battery" },
        bluetooth: { label: "Bluetooth", icon: "bluetooth" },
        clipboard: { label: "Clipboard", icon: "clipboard" },
        clock: { label: "Clock", icon: "calendar" },
        display: { label: "Displays", icon: "display" },
        media: { label: "Now playing", icon: "media" },
        microphone: { label: "Microphone", icon: "audio-input" },
        network: { label: "Network", icon: "wifi" },
        notes: { label: "Notes", icon: "notes" },
        notifications: { label: "Notifications", icon: "bell" },
        power: { label: "Power", icon: "power" },
        timer: { label: "Timer", icon: "timer" },
        tools: { label: "Tools", icon: "tools" },
        weather: { label: "Weather", icon: "cloud" }
    })
    // Dropdowns open across the bars.
    property int openDropdowns: 0

    // The bar on the screen named `screen` opens `panel`, or closes it when `toggle`
    // and it is open.
    signal requested(string panel, string screen, bool toggle)
    // The bars close their dropdowns.
    signal dismissRequested()

    function has(panel) {
        return Object.prototype.hasOwnProperty.call(root.panels, panel);
    }

    function isSupported(panel) {
        if (panel === "battery")
            return BatteryService.available;
        if (panel === "bluetooth")
            return FeatureSupport.supportsBluetooth;
        if (panel === "display")
            return FeatureSupport.supportsDisplayControl;
        if (panel === "media")
            return MediaService.player !== null;
        if (panel === "weather")
            return WeatherService.enabled;
        if (panel === "timer")
            return TimerService.timers.length > 0;
        return root.has(panel);
    }

    // The icon of a panel's bar button, showing its state.
    function icon(panel) {
        if (panel === "audio") {
            if (AudioService.output.muted)
                return "audio-output-muted";
            return AudioService.output.volumePercent <= 35 ? "audio-output-low" : "audio-output-high";
        }
        if (panel === "microphone")
            return AudioService.input.muted ? "audio-input-muted" : "audio-input";
        if (panel === "display")
            return BrightnessService.available ? "brightness" : "display";
        if (panel === "network") {
            if (RadioService.airplaneMode)
                return "airplane";
            if (VpnService.active)
                return "vpn";
            if (NetworkService.wiredDevice !== null)
                return "network-wired";
            const wifi = NetworkService.connectedWifi;
            return wifi !== null ? NetworkService.signalIcon(NetworkService.signalPercent(wifi.signalStrength)) : "wifi-off";
        }
        if (panel === "bluetooth")
            return BluetoothService.enabled ? "bluetooth" : "bluetooth-off";
        if (panel === "battery")
            return BatteryService.iconName;
        if (panel === "notifications")
            return NotificationService.dndEnabled ? "bell-off" : "bell";
        if (panel === "weather")
            return WeatherService.ready ? WeatherService.current.icon : "weather-cloudy";
        return root.has(panel) ? root.panels[panel].icon : "missing";
    }

    // A panel's state in a few words, for its bar button's label.
    function status(panel) {
        if (panel === "audio")
            return (AudioService.output.deviceLabel || "Volume") + ": " + AudioService.output.volumePercent + "%";
        if (panel === "microphone")
            return (AudioService.input.deviceLabel || "Mic") + ": " + AudioService.input.volumePercent + "%";
        if (panel === "display" && BrightnessService.available)
            return "Brightness: " + BrightnessService.percent + "%";
        if (panel === "network") {
            if (RadioService.airplaneMode)
                return "Airplane mode";
            if (NetworkService.wiredDevice)
                return "Ethernet";
            const wifi = NetworkService.connectedWifi;
            if (wifi)
                return "Wi-Fi: " + wifi.name;
            return NetworkService.wifiOn ? "Disconnected" : "Wi-Fi off";
        }
        if (panel === "bluetooth")
            return BluetoothService.enabled ? "Bluetooth on" : "Bluetooth off";
        if (panel === "battery")
            return BatteryService.ready ? "Battery: " + Math.round(BatteryService.percent) + "% · " + BatteryService.detail : "Battery";
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
        if (panel === "weather")
            return WeatherService.status === "unknown" ? "Weather: location not found" : WeatherService.summary || "Weather";
        return root.has(panel) ? root.panels[panel].label : "";
    }

    // Text beside a panel's icon on its bar button: the battery's charge, unless it
    // rests plugged in.
    function text(panel) {
        return panel === "battery" ? BatteryService.barText : "";
    }

    // The color of a panel's bar button icon when its state calls for one, else "".
    function tone(panel) {
        return panel === "battery" ? BatteryService.alertTone : "";
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
