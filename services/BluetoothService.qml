pragma Singleton
// Quickshell's type info leaves out BluetoothAdapter.
// qmllint disable unresolved-type

import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    property int scanDurationMs: 20000
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: root.adapter ? root.adapter.enabled : false
    readonly property bool scanning: root.adapter ? root.adapter.discovering : false

    function setEnabled(on) {
        if (root.adapter)
            root.adapter.enabled = on;
    }

    function startDiscovery() {
        if (!root.adapter || !root.enabled)
            return;

        root.adapter.discovering = true;
        discoveryTimeout.restart();
    }

    function stopDiscovery() {
        if (root.adapter)
            root.adapter.discovering = false;
        discoveryTimeout.stop();
    }

    // BlueZ names a device's class with a freedesktop icon name; map it to ours.
    function deviceIcon(device) {
        var icon = String(device && device.icon || "");
        if (icon.indexOf("audio-head") === 0)
            return "device-headphones";
        if (icon.indexOf("audio") === 0)
            return "device-speaker";
        if (icon === "input-gaming")
            return "device-gamepad";
        if (icon === "input-keyboard")
            return "device-keyboard";
        if (icon === "input-mouse" || icon === "input-tablet")
            return "device-mouse";
        if (icon === "phone")
            return "device-phone";
        if (icon === "computer")
            return "device-laptop";
        if (icon.indexOf("watch") >= 0)
            return "device-watch";
        return "bluetooth";
    }

    function toggleDiscovery() {
        if (root.scanning)
            root.stopDiscovery();
        else
            root.startDiscovery();
    }

    onEnabledChanged: {
        if (!root.enabled)
            root.stopDiscovery();
    }

    onAdapterChanged: {
        if (!root.adapter)
            discoveryTimeout.stop();
    }

    onScanningChanged: {
        if (!root.scanning)
            discoveryTimeout.stop();
    }

    Timer {
        id: discoveryTimeout
        interval: root.scanDurationMs
        repeat: false
        onTriggered: root.stopDiscovery()
    }
}
