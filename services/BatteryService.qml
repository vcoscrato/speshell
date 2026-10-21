pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../components/Format.js" as Format
import "../components/Icons.js" as Icons

// The laptop battery through UPower: its charge and what it's doing, a warning as it
// runs low, its health and power draw, and the charge limit; and the charge of other
// devices, as a mouse or headphones.
Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool available: FeatureSupport.supportsBattery
    readonly property bool ready: root.device !== null && root.device.ready
    readonly property real percent: root.ready ? root.device.percentage * 100 : 0
    readonly property bool pluggedIn: !UPower.onBattery
    readonly property bool charging: root.ready && root.device.state === UPowerDeviceState.Charging
    readonly property bool full: root.ready && root.device.state === UPowerDeviceState.FullyCharged
    // Plugged in and not charging: full, or stopped at the charge limit.
    readonly property bool resting: root.pluggedIn && !root.charging
        && (root.full || root.percent >= root.activeChargeLimit - 5)

    // The bar's percent, shown unless the battery rests plugged in.
    readonly property string barText: root.available && root.ready && !root.resting
        ? Math.round(root.percent) + "%" : ""
    readonly property string iconName: root.ready ? Icons.batteryFor(root.percent, root.pluggedIn) : "battery"
    readonly property string tone: root.pluggedIn ? "success"
        : root.percent <= root.criticalLevel ? "error"
        : root.percent <= root.lowLevel ? "warning" : "accent"
    // The bar icon's tone: only running low calls for one.
    readonly property string alertTone: root.ready && (root.tone === "warning" || root.tone === "error") ? root.tone : ""

    // What it's doing, in a few words: "Charging · full in 1 h 5 min", "3 h 20 min left".
    readonly property string detail: {
        if (!root.ready)
            return "";
        if (root.full)
            return "Fully charged";
        if (root.charging) {
            const toFull = root.duration(root.device.timeToFull);
            return toFull !== "" ? "Charging · full in " + toFull : "Charging";
        }
        if (root.pluggedIn)
            return root.resting && root.activeChargeLimit < 100 ? "Held at the charge limit" : "Plugged in, not charging";
        const toEmpty = root.duration(root.device.timeToEmpty);
        return toEmpty !== "" ? toEmpty + " left" : "On battery";
    }

    // The battery's capacity now against its design, in percent, or -1 when unknown.
    readonly property real health: root.laptopBattery && root.laptopBattery.healthSupported
        ? root.laptopBattery.healthPercentage : -1
    // Watts in or out, or 0 when unknown or a mere trickle, as when full.
    readonly property real watts: root.ready && Math.abs(root.device.changeRate) >= 0.1 ? Math.abs(root.device.changeRate) : 0

    // [Battery] lowLevel and criticalLevel, and whether each was told this discharge.
    readonly property int lowLevel: ConfigService.settings.battery.lowLevel
    readonly property int criticalLevel: ConfigService.settings.battery.criticalLevel
    property bool lowNotified: false
    property bool criticalNotified: false

    // The laptop's own battery, as BAT0: the display device is UPower's sum of them.
    readonly property var laptopBattery: root.upowerDevices().find(device => device.isLaptopBattery && device.isPresent) || null
    readonly property string batteryName: root.laptopBattery ? String(root.laptopBattery.nativePath || "") : ""
    // Other devices' charge, as {name, iconName, percent}.
    readonly property var peripherals: root.upowerDevices()
        .filter(device => device.ready && !device.powerSupply && device.type !== UPowerDeviceType.LinePower
            && device.percentage > 0)
        .map(device => ({
            name: device.model || UPowerDeviceType.toString(device.type),
            iconName: root.peripheralIcon(device.type),
            percent: Math.round(device.percentage * 100)
        }))

    // [Battery] chargeLimit: charging stops there and resumes 5 points below; 100 leaves
    // it to the firmware. Written through tools/charge-limit, as root.
    readonly property int chargeLimit: ConfigService.settings.battery.chargeLimit
    // charge_control_end_threshold, or -1 without one; the charge type in use, as
    // Dell's "Custom", or "" without charge_types.
    property int endThreshold: -1
    property string chargeType: ""
    // Whether charge_types was read, or found missing.
    property bool chargeTypeKnown: false
    readonly property bool supportsChargeLimit: root.batteryName !== "" && root.endThreshold >= 0
    // The limit the battery has now: its end threshold, or 100 where the charge type
    // leaves thresholds unused.
    readonly property int activeChargeLimit: !root.supportsChargeLimit
        || (root.chargeType !== "" && root.chargeType !== "Custom") ? 100 : root.endThreshold
    property string chargeLimitError: ""
    property int queuedChargeLimit: -1
    property bool chargeLimitSynced: false

    // Untyped: Quickshell's type info leaves the model's values out.
    readonly property var deviceModel: UPower.devices

    function upowerDevices() {
        return root.deviceModel && root.deviceModel.values ? root.deviceModel.values : [];
    }

    // "2 h 5 min", to the minute, or "" when unknown.
    function duration(seconds) {
        return seconds > 0 ? Format.duration(Math.max(60, Math.round(seconds / 60) * 60)) : "";
    }

    function peripheralIcon(type) {
        if (type === UPowerDeviceType.Mouse || type === UPowerDeviceType.Touchpad)
            return "device-mouse";
        if (type === UPowerDeviceType.Keyboard)
            return "device-keyboard";
        if (type === UPowerDeviceType.Headset || type === UPowerDeviceType.Headphones)
            return "device-headphones";
        if (type === UPowerDeviceType.Speakers || type === UPowerDeviceType.OtherAudio)
            return "device-speaker";
        if (type === UPowerDeviceType.GamingInput)
            return "device-gamepad";
        if (type === UPowerDeviceType.Phone || type === UPowerDeviceType.Tablet)
            return "device-phone";
        if (type === UPowerDeviceType.Wearable)
            return "device-watch";
        return "battery";
    }

    // Notifies once per discharge as the charge reaches lowLevel, then criticalLevel;
    // plugging in takes the warning back.
    function checkLevel() {
        if (!root.available || !root.ready)
            return;
        if (root.pluggedIn) {
            if (root.lowNotified)
                NotificationService.dismissInternal("battery");
            root.lowNotified = false;
            root.criticalNotified = false;
            return;
        }
        const percent = Math.round(root.percent);
        const left = root.duration(root.device.timeToEmpty);
        const body = percent + "% left" + (left !== "" ? ", about " + left : "") + ". Plug in soon.";
        if (percent <= root.criticalLevel && !root.criticalNotified) {
            root.criticalNotified = true;
            root.lowNotified = true;
            NotificationService.addInternalNotification("battery", "Battery critically low", body, true, 2);
        } else if (percent <= root.lowLevel && !root.lowNotified) {
            root.lowNotified = true;
            NotificationService.addInternalNotification("battery", "Battery low", body);
        }
    }

    // Picked in the Battery panel: saved to config.ini and applied.
    function setChargeLimit(limit) {
        ConfigService.setProperty("Battery", "chargeLimit", limit);
        root.applyChargeLimit(limit);
    }

    function applyChargeLimit(limit) {
        if (!root.supportsChargeLimit || limit === root.activeChargeLimit)
            return;
        if (chargeLimitProc.running) {
            root.queuedChargeLimit = limit;
            return;
        }
        root.chargeLimitError = "";
        chargeLimitProc.command = ["pkexec", SystemState.appDir + "/tools/charge-limit", root.batteryName, String(limit)];
        chargeLimitProc.running = true;
    }

    // Once the battery is read: a limit below 100 in config.ini is applied, as after
    // firmware that forgets it. 100 leaves the firmware's setting alone.
    function syncChargeLimit() {
        if (root.chargeLimitSynced || !root.supportsChargeLimit || !root.chargeTypeKnown)
            return;
        root.chargeLimitSynced = true;
        if (root.chargeLimit < 100)
            root.applyChargeLimit(root.chargeLimit);
    }

    onPercentChanged: root.checkLevel()
    onPluggedInChanged: root.checkLevel()
    onReadyChanged: root.checkLevel()
    onSupportsChargeLimitChanged: Qt.callLater(root.syncChargeLimit)
    onChargeTypeKnownChanged: Qt.callLater(root.syncChargeLimit)
    // An edit to config.ini.
    onChargeLimitChanged: if (root.chargeLimitSynced) root.applyChargeLimit(root.chargeLimit)

    FileView {
        id: endThresholdFile

        function read() {
            const value = parseInt(endThresholdFile.text(), 10);
            root.endThreshold = isNaN(value) ? -1 : Math.max(0, Math.min(100, value));
        }

        path: root.batteryName !== "" ? "/sys/class/power_supply/" + root.batteryName + "/charge_control_end_threshold" : ""
        printErrors: false
        watchChanges: true
        onLoaded: endThresholdFile.read()
        onTextChanged: endThresholdFile.read()
        onFileChanged: reload()
    }

    // "Trickle Fast Standard [Custom]": the one in brackets is in use.
    FileView {
        id: chargeTypesFile

        function read() {
            root.chargeType = (chargeTypesFile.text().match(/\[(\w+)\]/) || [])[1] || "";
        }

        path: root.batteryName !== "" ? "/sys/class/power_supply/" + root.batteryName + "/charge_types" : ""
        printErrors: false
        watchChanges: true
        onLoaded: {
            chargeTypesFile.read();
            root.chargeTypeKnown = true;
        }
        onLoadFailed: root.chargeTypeKnown = true
        onTextChanged: chargeTypesFile.read()
        onFileChanged: reload()
    }

    Process {
        id: chargeLimitProc
        running: false
        stderr: StdioCollector { id: chargeLimitStderr }
        onExited: function(exitCode) {
            // 126: the authorization was dismissed.
            if (exitCode === 126)
                root.chargeLimitError = "Changing the charge limit wasn't authorized.";
            else if (exitCode !== 0)
                root.chargeLimitError = (chargeLimitStderr.text || "").trim().split("\n")[0] || "Could not set the charge limit.";
            endThresholdFile.reload();
            chargeTypesFile.reload();
            if (root.queuedChargeLimit >= 0) {
                const next = root.queuedChargeLimit;
                root.queuedChargeLimit = -1;
                Qt.callLater(() => root.applyChargeLimit(next));
            }
        }
    }
}
