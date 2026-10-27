pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import qs.components
import qs.services

// Bluetooth on and off, and the connected, paired, and nearby devices.
Card {
    id: root
    title: "Bluetooth"
    iconName: "bluetooth"
    property bool presented: false

    readonly property var adapter: BluetoothService.adapter
    readonly property bool btOn: BluetoothService.enabled
    readonly property bool scanning: BluetoothService.scanning

    // Scanning waits for the refresh button; closing the panel stops it.
    onPresentedChanged: if (!root.presented && root.scanning) BluetoothService.stopDiscovery()
    Component.onDestruction: if (BluetoothService.scanning) BluetoothService.stopDiscovery()

    function devicesWhere(test) {
        if (!root.adapter) return [];
        var result = [];
        for (var i = 0; i < root.adapter.devices.values.length; i++) {
            var dev = root.adapter.devices.values[i];
            if (test(dev)) result.push(dev);
        }
        return result;
    }

    readonly property var connectedDevices: root.devicesWhere(function(dev) { return dev.connected; })
    readonly property var knownDevices: root.devicesWhere(function(dev) { return dev.paired && !dev.connected; })
    readonly property var discoveredDevices: root.devicesWhere(function(dev) { return !dev.paired && !dev.connected; })
    readonly property int deviceCount: root.connectedDevices.length + root.knownDevices.length
        + root.discoveredDevices.length
    readonly property bool anyBusy: root.devicesWhere(function(dev) { return root.isBusy(dev); }).length > 0

    function isBusy(dev) {
        return dev.state === BluetoothDeviceState.Connecting
            || dev.state === BluetoothDeviceState.Disconnecting;
    }

    function deviceSubtitle(dev) {
        if (dev.state === BluetoothDeviceState.Connecting) return "Connecting…";
        if (dev.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…";
        var parts = [dev.connected ? "Connected" : (dev.paired ? "Paired" : "Available")];
        if (dev.batteryAvailable)
            parts.push("Battery " + Math.round(dev.battery * 100) + "%");
        return parts.join(" · ");
    }

    function deviceActions(dev) {
        var busy = root.isBusy(dev);
        if (dev.connected)
            return [{ text: "Disconnect", enabled: !busy, actionId: "disconnect" }];
        return [{ text: "Connect", enabled: !busy, actionId: "connect" }];
    }

    headerActions: Row {
        spacing: Theme.spacingSmall

        HeaderButton {
            iconName: "refresh"
            visible: root.btOn
            busy: root.presented && root.scanning
            tooltipText: root.scanning ? "Stop Bluetooth scan" : "Scan for Bluetooth devices"
            onClicked: BluetoothService.toggleDiscovery()
        }

        ToggleSwitch {
            enabled: root.adapter !== null
            checked: root.btOn
            tooltipText: root.btOn ? "Turn Bluetooth off" : "Turn Bluetooth on"
            onToggled: function(state) { BluetoothService.setEnabled(state); }
        }
    }

    component DeviceList: Column {
        id: list

        property string title: ""
        property var devices: []

        width: parent.width
        spacing: Theme.spacingTiny
        visible: root.btOn && list.devices.length > 0

        DeviceSection {
            title: list.title
            count: list.devices.length
        }

        Item { width: 1; height: Theme.spacingTiny }

        Repeater {
            model: list.devices
            delegate: DeviceRow {
                id: deviceRow
                required property var modelData
                title: deviceRow.modelData.name
                subtitle: root.deviceSubtitle(deviceRow.modelData)
                iconName: BluetoothService.deviceIcon(deviceRow.modelData)
                current: deviceRow.modelData.connected
                busy: root.isBusy(deviceRow.modelData)
                primaryEnabled: false
                actions: root.deviceActions(deviceRow.modelData)
                opacity: root.anyBusy && !deviceRow.busy ? 0.5 : 1.0
                onActionTriggered: function(actionId) {
                    if (actionId === "disconnect") deviceRow.modelData.disconnect();
                    if (actionId === "connect") deviceRow.modelData.connect();
                }

                Behavior on opacity {
                    NumberAnimation { duration: Theme.animDuration }
                }
            }
        }
    }

    pinnedContent: [
        DeviceList {
            title: "Connected"
            devices: root.connectedDevices
        },

        EmptyState {
            visible: root.adapter === null
            iconName: "bluetooth-off"
            title: "No Bluetooth adapter"
            detail: "This computer has no Bluetooth adapter Speshell can use."
        },

        EmptyState {
            visible: root.adapter !== null && !root.btOn
            iconName: "bluetooth-off"
            title: "Bluetooth is off"
            detail: "Turn it on to connect headphones, controllers, and other devices."
            actionLabel: "Turn on Bluetooth"
            actionIconName: "bluetooth"
            onActivated: BluetoothService.setEnabled(true)
        }
    ]

    Column {
        width: parent.width
        spacing: Theme.spacingMedium

        DeviceList {
            title: "Paired"
            devices: root.knownDevices
        }

        DeviceList {
            title: "Nearby"
            devices: root.discoveredDevices
        }

        EmptyState {
            visible: root.btOn && (root.deviceCount === 0 || (root.scanning && root.discoveredDevices.length === 0))
            iconName: "bluetooth"
            busy: root.scanning
            title: root.scanning ? "Looking for devices…" : "No devices yet"
            detail: root.scanning ? "Put the device in pairing mode to find it."
                : "Put a device in pairing mode, then scan for it."
            actionLabel: root.scanning ? "" : "Scan"
            actionIconName: "refresh"
            onActivated: BluetoothService.startDiscovery()
        }
    }
}
