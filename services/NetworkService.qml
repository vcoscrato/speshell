pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Networking
import "../components/Format.js" as Format

// Wi-Fi and wired networking through NetworkManager: the devices, the connected and
// nearby networks, scans, and connecting with a password typed in the panel. Networks
// seen in a scan stay listed for a while, out of range once they go.
Singleton {
    id: root

    readonly property int scanDurationMs: 30000
    readonly property int cacheMaxAgeMs: 10 * 60 * 1000
    property var cachedNetworks: []
    // Millisecond timestamps exceed the 32-bit int range; keep them as doubles.
    property double cacheUpdatedAtMs: 0
    property double nowMs: Date.now()
    // Whether the user scanned this session, so an empty list can say what it means.
    property bool scanRequested: false

    // The password prompt, on the row of the network named; the last connection error
    // and the network it's for.
    property string passwordRowName: ""
    property string passwordText: ""
    property string connectErrorName: ""
    property string connectError: ""
    property var pendingNetwork: null
    property string pendingNetworkName: ""

    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property var wifiDevice: root.findWifiDevice()
    readonly property var wiredDevice: root.findWiredDevice()
    readonly property var connectedWifi: root.wifiNetworks(function(network) { return network.connected; })[0] || null
    readonly property var connectingNetwork: root.wifiNetworks(function(network) {
        return network.state === ConnectionState.Connecting;
    })[0] || null
    readonly property var otherNetworks: root.wifiNetworks(function(network) {
        return !network.connected && network.state !== ConnectionState.Connecting;
    })
    readonly property var displayedNetworks: root.buildDisplayedNetworks()
    readonly property bool isScanning: root.wifiDevice ? root.wifiDevice.scannerEnabled : false

    function setWifiEnabled(on) {
        Networking.wifiEnabled = on;
    }

    function findWifiDevice() {
        for (var i = 0; i < Networking.devices.values.length; i++) {
            var dev = Networking.devices.values[i];
            if (dev.type === DeviceType.Wifi) return dev;
        }
        return null;
    }

    function findWiredDevice() {
        for (var i = 0; i < Networking.devices.values.length; i++) {
            var dev = Networking.devices.values[i];
            if (dev.type === DeviceType.Wired && dev.connected) return dev;
        }
        return null;
    }

    // The Wi-Fi device's networks that pass `test`.
    function wifiNetworks(test) {
        var result = [];
        var networks = root.wifiDevice ? root.wifiDevice.networks.values : [];
        for (var i = 0; i < networks.length; i++) {
            if (test(networks[i]))
                result.push(networks[i]);
        }
        return result;
    }

    function networkKey(network) {
        return network ? String(network.name || "") + "|" + String(network.security) : "|";
    }

    function signalPercent(value) {
        return Math.round((Number(value) || 0) * 100);
    }

    function signalIcon(level) {
        if (level > 75) return "wifi";
        if (level > 50) return "wifi-medium";
        if (level > 25) return "wifi-low";
        return "wifi-empty";
    }

    function networkSnapshot(network, now) {
        return {
            key: root.networkKey(network),
            name: network.name || "Hidden network",
            signalStrength: Number(network.signalStrength) || 0,
            signalLevel: root.signalPercent(network.signalStrength),
            security: network.security,
            known: !!network.known,
            stateChanging: !!network.stateChanging,
            network: network,
            live: true,
            lastSeenMs: now
        };
    }

    function findLiveNetwork(item) {
        if (!item)
            return null;
        return root.wifiNetworks(function(network) { return root.networkKey(network) === item.key; })[0] || null;
    }

    function sortNetworks(items) {
        items.sort(function(a, b) {
            if (!!a.known !== !!b.known) {
                return a.known ? -1 : 1;
            }
            if (a.signalLevel !== b.signalLevel) {
                return b.signalLevel - a.signalLevel;
            }
            return String(a.name).localeCompare(String(b.name));
        });
        return items;
    }

    function refreshNetworkCache() {
        var networks = root.otherNetworks;
        if (!networks || networks.length === 0) {
            return;
        }

        var now = Date.now();
        var byKey = {};
        var kept = [];

        for (var i = 0; i < root.cachedNetworks.length; i++) {
            var cached = root.cachedNetworks[i];
            if (cached && now - cached.lastSeenMs <= root.cacheMaxAgeMs) {
                byKey[cached.key] = cached;
            }
        }

        for (i = 0; i < networks.length; i++) {
            var snapshot = root.networkSnapshot(networks[i], now);
            byKey[snapshot.key] = snapshot;
        }

        for (var key in byKey) {
            kept.push(byKey[key]);
        }

        root.cachedNetworks = root.sortNetworks(kept);
        root.cacheUpdatedAtMs = now;
        root.nowMs = now;
    }

    function clearNetworkCache() {
        root.cachedNetworks = [];
        root.cacheUpdatedAtMs = 0;
    }

    function connectedNetworkKey() {
        return root.connectedWifi ? root.networkKey(root.connectedWifi) : "";
    }

    // One row per network name: a snapshot taken before NetworkManager reported a
    // network's security has another key, so names, not keys, decide what repeats.
    function buildDisplayedNetworks() {
        var byName = {};
        var connectedKey = root.connectedNetworkKey();
        var connectedName = root.connectedWifi ? root.connectedWifi.name : "";
        var now = root.nowMs;

        for (var i = 0; i < root.cachedNetworks.length; i++) {
            var cached = root.cachedNetworks[i];
            if (!cached || cached.key === connectedKey || now - cached.lastSeenMs > root.cacheMaxAgeMs
                    || (connectedName !== "" && cached.name === connectedName)) {
                continue;
            }

            var liveNetwork = root.findLiveNetwork(cached);
            var item = {
                key: cached.key,
                name: cached.name,
                signalStrength: liveNetwork ? Number(liveNetwork.signalStrength) || 0 : cached.signalStrength,
                signalLevel: liveNetwork ? root.signalPercent(liveNetwork.signalStrength) : cached.signalLevel,
                security: liveNetwork ? liveNetwork.security : cached.security,
                known: liveNetwork ? !!liveNetwork.known : !!cached.known,
                stateChanging: liveNetwork ? !!liveNetwork.stateChanging : false,
                network: liveNetwork || null,
                live: liveNetwork !== null,
                lastSeenMs: cached.lastSeenMs
            };
            var seen = byName[item.name];
            if (!seen || (item.live && !seen.live) || (item.live === seen.live && item.signalLevel > seen.signalLevel))
                byName[item.name] = item;
        }

        var result = [];
        for (var name in byName)
            result.push(byName[name]);
        return root.sortNetworks(result);
    }

    // The nearby list's status, beside its title.
    function nearbyStatusText() {
        if (root.isScanning)
            return "Scanning…";
        if (root.cacheUpdatedAtMs > 0 && (root.scanRequested || root.displayedNetworks.length > 0))
            return "Updated " + Format.ago(root.cacheUpdatedAtMs, root.nowMs);
        return "";
    }

    function isOpen(security) {
        return security === WifiSecurityType.Open || security === WifiSecurityType.Owe;
    }

    function networkSubtitle(item) {
        if (!item) {
            return "";
        }
        if (item.stateChanging) {
            return "Connecting…";
        }
        var parts = [];
        if (item.known)
            parts.push("Saved");
        parts.push(root.isOpen(item.security) ? "Open" : "Secured");
        parts.push(item.signalLevel + "%");
        if (!item.live)
            parts.push("out of range");
        return parts.join(" · ");
    }

    function connectedSubtitle() {
        var network = root.connectedWifi;
        if (!network)
            return "";
        return ["Connected", root.isOpen(network.security) ? "Open" : "Secured",
                root.signalPercent(network.signalStrength) + "%"].join(" · ");
    }

    // A click on a nearby network's row: connects to a saved or open one, or asks for
    // the password.
    function activate(item) {
        var network = root.findLiveNetwork(item);
        if (!network) {
            root.startWifiScan();
            return;
        }
        if (network.connected)
            return;
        if (network.known || root.isOpen(network.security)) {
            root.beginConnection(network, "");
            return;
        }
        if (!root.supportsPsk(network.security)) {
            root.connectErrorName = network.name;
            root.connectError = "This network needs settings that Speshell cannot request. Configure it in NetworkManager first.";
            return;
        }
        var opening = root.passwordRowName !== network.name;
        root.cancelPasswordPrompt();
        if (opening)
            root.passwordRowName = network.name;
    }

    function connectWithPassword(item, psk) {
        var network = root.findLiveNetwork(item);
        if (!network) {
            root.startWifiScan();
            return;
        }
        root.requestConnect(network, psk);
    }

    function cancelPasswordPrompt() {
        root.passwordRowName = "";
        root.passwordText = "";
        root.connectErrorName = "";
        root.connectError = "";
    }

    function supportsPsk(security) {
        return security === WifiSecurityType.WpaPsk
            || security === WifiSecurityType.Wpa2Psk
            || security === WifiSecurityType.Sae;
    }

    function beginConnection(network, psk) {
        root.stopWifiScan();
        root.pendingNetwork = network;
        root.pendingNetworkName = network.name || "Network";
        root.connectErrorName = "";
        root.connectError = "";
        if (psk !== "")
            network.connectWithPsk(psk);
        else
            network.connect();
        root.passwordText = "";
    }

    function requestConnect(network, psk) {
        var password = String(psk || "");
        if (!root.supportsPsk(network.security)) {
            root.connectErrorName = network.name;
            root.connectError = "Password entry is not supported for this network type.";
            return;
        }
        var minimumLength = network.security === WifiSecurityType.Sae ? 1 : 8;
        if (password.length < minimumLength) {
            root.connectErrorName = network.name;
            root.connectError = minimumLength === 1
                ? "Enter the network password."
                : "Enter a password with at least 8 characters.";
            return;
        }
        root.beginConnection(network, password);
    }

    function connectionFailureText(reason) {
        var reasonName = ConnectionFailReason.toString(reason);
        if (reason === ConnectionFailReason.NoSecrets)
            return "A password is required or the saved password was rejected.";
        if (reason === ConnectionFailReason.WifiAuthTimeout || reason === ConnectionFailReason.WifiClientFailed)
            return "Authentication failed. Check the password and try again.";
        if (reason === ConnectionFailReason.WifiNetworkLost)
            return "The network is no longer available. Refresh and try again.";
        return reasonName && reasonName !== "Unknown"
            ? "Connection failed: " + reasonName + "."
            : "Could not connect to the network.";
    }

    function handleConnectionFailed(reason) {
        root.connectErrorName = root.pendingNetworkName;
        root.connectError = root.connectionFailureText(reason);
        if (root.pendingNetwork && root.supportsPsk(root.pendingNetwork.security))
            root.passwordRowName = root.pendingNetworkName;
        root.pendingNetwork = null;
    }

    function startWifiScan() {
        if (!root.wifiDevice || !root.wifiOn)
            return;
        root.scanRequested = true;
        root.wifiDevice.scannerEnabled = true;
        wifiScanTimeoutTimer.restart();
    }

    function stopWifiScan() {
        if (root.wifiDevice)
            root.wifiDevice.scannerEnabled = false;
        wifiScanTimeoutTimer.stop();
    }

    function toggleWifiScan() {
        if (root.isScanning) {
            root.stopWifiScan();
        } else {
            root.startWifiScan();
        }
    }

    onWifiOnChanged: {
        if (!root.wifiOn) {
            root.stopWifiScan();
            root.clearNetworkCache();
            root.pendingNetwork = null;
            root.cancelPasswordPrompt();
        }
    }

    onConnectedWifiChanged: {
        if (root.connectedWifi !== null && root.pendingNetwork !== null) {
            root.pendingNetwork = null;
            root.pendingNetworkName = "";
            root.cancelPasswordPrompt();
        }
    }

    Connections {
        target: root.pendingNetwork
        function onConnectionFailed(reason) {
            root.handleConnectionFailed(reason);
        }
    }

    onWifiDeviceChanged: {
        if (!root.wifiDevice) {
            wifiScanTimeoutTimer.stop();
            root.clearNetworkCache();
        }
    }

    onOtherNetworksChanged: root.refreshNetworkCache()

    onIsScanningChanged: {
        if (!root.isScanning)
            wifiScanTimeoutTimer.stop();
    }

    Component.onCompleted: root.refreshNetworkCache()

    Timer {
        id: wifiScanTimeoutTimer
        interval: root.scanDurationMs
        repeat: false
        onTriggered: root.stopWifiScan()
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.cacheUpdatedAtMs > 0
        onTriggered: root.nowMs = Date.now()
    }
}
