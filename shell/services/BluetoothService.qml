pragma Singleton
// Quickshell's type info leaves out BluetoothAdapter.
// qmllint disable unresolved-type

import QtQuick
import Quickshell
import Quickshell.Bluetooth

// The default Bluetooth adapter: on and off, discovery with a timeout, connecting
// (pairing a new device first), and an icon for each kind of device.
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

    // The device a connect is pairing first, and the last one that failed to pair; null
    // when none.
    property var pairing: null
    property var pairFailed: null

    // A device not yet paired is paired first, then trusted so it reconnects on its own,
    // then connected.
    function connectDevice(device, on) {
        if (!on) {
            device.disconnect();
            return;
        }
        root.pairFailed = null;
        if (device.paired) {
            device.connect();
            return;
        }
        root.pairing = device;
        device.pair();
    }

    function cancelPairing() {
        if (root.pairing)
            root.pairing.cancelPair();
    }

    // When the device is paired, or its pairing has ended without, whichever is heard first.
    function settlePairing() {
        const device = root.pairing;
        if (!device || (device.pairing && !device.paired))
            return;
        root.pairing = null;
        if (device.paired) {
            device.trusted = true;
            device.connect();
        } else {
            root.pairFailed = device;
        }
    }

    // BlueZ names a device's class with a freedesktop icon name; map it to ours.
    function deviceIcon(device) {
        const icon = String(device && device.icon || "");
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

    Connections {
        target: root.pairing

        function onPairedChanged() {
            root.settlePairing();
        }

        function onPairingChanged() {
            root.settlePairing();
        }
    }

    Timer {
        id: discoveryTimeout
        interval: root.scanDurationMs
        repeat: false
        onTriggered: root.stopDiscovery()
    }
}
