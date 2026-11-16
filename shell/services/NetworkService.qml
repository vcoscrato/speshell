pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "../components/Format.js" as Format
import "Shell.js" as Shell

// Wi-Fi and wired networking through NetworkManager. Quickshell follows the devices, the
// connected network, and the saved ones. The networks nearby come from NetworkManager's
// access points, read with nmcli: Quickshell lists unsaved networks only while its
// scanner runs, and that scanner asks for a new scan every ten seconds, which stalls
// 2.4 GHz input devices on some cards. Here a scan is one nmcli rescan, only when the
// user asks; it can't be stopped once it starts, and what it found stays listed for ten
// minutes. Joining a new network adds a profile for it, sets the password through nmcli's
// editor so it never shows on a command line, and deletes the profile if joining fails.
Singleton {
    id: root

    readonly property int listMaxAgeMs: 10 * 60 * 1000

    // [{ name, signalLevel, security (nmcli's words), seenMs }], one per network name.
    property var accessPoints: []
    // Millisecond timestamps exceed the 32-bit int range; keep them as doubles.
    property double scannedAtMs: 0
    property double nowMs: Date.now()
    readonly property bool isScanning: scanProc.running

    // What the user is doing with the network `name`, or null: { kind, name, network,
    // secured, error }. `kind` is "password" (its row asks for one, `error` saying why
    // when it was rejected), "connect" (the saved `network` connects through
    // Quickshell), "join" (a new network is being added, `secured` with a password), or
    // "failed" (`error` says why).
    property var operation: null
    readonly property string passwordRowName: root.operationName("password")
    readonly property string joiningName: root.operationName("join")
    readonly property string connectErrorName: root.operation && root.operation.error ? root.operation.name : ""
    readonly property string connectError: root.operation && root.operation.error ? root.operation.error : ""

    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property var wifiDevice: root.findWifiDevice()
    readonly property var wiredDevice: root.findWiredDevice()
    readonly property var connectedWifi: root.wifiNetworks(network => network.connected)[0] || null
    readonly property var connectingNetwork: root.wifiNetworks(network => {
        return network.state === ConnectionState.Connecting;
    })[0] || null
    readonly property var displayedNetworks: root.buildDisplayedNetworks()

    function setWifiEnabled(on) {
        Networking.wifiEnabled = on;
    }

    function disconnectWifi() {
        if (root.connectedWifi)
            root.connectedWifi.disconnect();
    }

    // The network `operation` is about, when it is of `kind`; else "".
    function operationName(kind) {
        return root.operation && root.operation.kind === kind ? root.operation.name : "";
    }

    // Drops a nearby network's saved connection, password and all.
    function forget(item) {
        if (item.network)
            item.network.forget();
    }

    function findWifiDevice() {
        for (let i = 0; i < Networking.devices.values.length; i++) {
            const dev = Networking.devices.values[i];
            if (dev.type === DeviceType.Wifi) return dev;
        }
        return null;
    }

    function findWiredDevice() {
        for (let i = 0; i < Networking.devices.values.length; i++) {
            const dev = Networking.devices.values[i];
            if (dev.type === DeviceType.Wired && dev.connected) return dev;
        }
        return null;
    }

    // The networks Quickshell lists that pass `test`: without its scanner, the saved
    // ones and the connected one.
    function wifiNetworks(test) {
        const result = [];
        const networks = root.wifiDevice ? root.wifiDevice.networks.values : [];
        for (let i = 0; i < networks.length; i++) {
            if (test(networks[i]))
                result.push(networks[i]);
        }
        return result;
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

    // nmcli -t lines of SIGNAL:SECURITY:SSID; it escapes ':' and '\' in the SSID, which
    // comes last. Hidden networks have no name and stay out.
    function parseList(text, now) {
        const byName = {};
        const lines = String(text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const fields = lines[i].split(":");
            if (fields.length < 3)
                continue;
            const name = fields.slice(2).join(":").replace(/\\(.)/g, "$1");
            const level = Number(fields[0]) || 0;
            if (name !== "" && (!byName[name] || level > byName[name].signalLevel))
                byName[name] = { name: name, signalLevel: level, security: fields[1], seenMs: now };
        }
        return byName;
    }

    function listOf(byName) {
        const result = [];
        for (const name in byName)
            result.push(byName[name]);
        return result;
    }

    // A scan's list replaces what was there; a look at NetworkManager's list adds to it,
    // since NetworkManager forgets networks a few minutes after a scan.
    function takeList(text, scanned) {
        const now = Date.now();
        const found = root.parseList(text, now);
        if (!scanned) {
            for (let i = 0; i < root.accessPoints.length; i++) {
                const known = root.accessPoints[i];
                if (!found[known.name] && now - known.seenMs <= root.listMaxAgeMs)
                    found[known.name] = known;
            }
        }
        root.accessPoints = root.listOf(found);
        if (scanned)
            root.scannedAtMs = now;
        root.nowMs = now;
    }

    // NetworkManager's list as it stands; it never scans.
    function refreshList() {
        if (root.wifiDevice && root.wifiOn && !scanProc.running)
            listProc.request();
    }

    function scan() {
        if (root.wifiDevice && root.wifiOn && !scanProc.running)
            scanProc.running = true;
    }

    function listCommand(rescan) {
        const command = ["nmcli", "-t", "-f", "SIGNAL,SECURITY,SSID", "device", "wifi", "list"];
        if (root.wifiDevice && root.wifiDevice.name)
            command.push("ifname", root.wifiDevice.name);
        return command.concat(["--rescan", rescan ? "yes" : "no"]);
    }

    function savedNetwork(name) {
        return root.wifiNetworks(network => network.known && network.name === name)[0] || null;
    }

    function buildDisplayedNetworks() {
        const connectedName = root.connectedWifi ? root.connectedWifi.name : "";
        const result = [];
        for (let i = 0; i < root.accessPoints.length; i++) {
            const point = root.accessPoints[i];
            if (point.name === connectedName || root.nowMs - point.seenMs > root.listMaxAgeMs)
                continue;
            const saved = root.savedNetwork(point.name);
            result.push({
                name: point.name,
                signalLevel: point.signalLevel,
                security: point.security,
                network: saved,
                stateChanging: (saved !== null && saved.stateChanging) || root.joiningName === point.name
            });
        }
        return result.sort((a, b) => {
            if ((a.network !== null) !== (b.network !== null))
                return a.network !== null ? -1 : 1;
            if (a.signalLevel !== b.signalLevel)
                return b.signalLevel - a.signalLevel;
            return a.name.localeCompare(b.name);
        });
    }

    // The nearby list's status, beside its title.
    function nearbyStatusText() {
        if (root.isScanning)
            return "Scanning…";
        if (root.scannedAtMs > 0)
            return "Scanned " + Format.ago(root.scannedAtMs, root.nowMs);
        return "";
    }

    // How a new network is joined, from nmcli's SECURITY: "open", "owe", "wpa-psk",
    // "sae", or "" when it needs more than a password (WEP, 802.1X).
    function joinKind(security) {
        if (security === "" || security === "--")
            return "open";
        if (/802\.1X|WEP/.test(security))
            return "";
        if (/WPA1|WPA2/.test(security))
            return "wpa-psk";
        if (/WPA3/.test(security))
            return "sae";
        return /OWE/.test(security) ? "owe" : "";
    }

    function isOpenSecurity(security) {
        return security === WifiSecurityType.Open || security === WifiSecurityType.Owe;
    }

    function networkSubtitle(item) {
        if (item.stateChanging)
            return "Connecting…";
        const kind = root.joinKind(item.security);
        const parts = [];
        if (item.network)
            parts.push("Saved");
        parts.push(kind === "open" || kind === "owe" ? "Open" : "Secured");
        parts.push(item.signalLevel + "%");
        return parts.join(" · ");
    }

    function connectedSubtitle() {
        const network = root.connectedWifi;
        if (!network)
            return "";
        return ["Connected", root.isOpenSecurity(network.security) ? "Open" : "Secured",
                root.signalPercent(network.signalStrength) + "%"].join(" · ");
    }

    // A click on a nearby network's row: connects to a saved or open one, or asks for
    // the password.
    function activate(item) {
        if (item.stateChanging || root.joiningName !== "")
            return;
        if (item.network) {
            if (!item.network.connected)
                root.beginConnection(item.network, "");
            return;
        }
        const kind = root.joinKind(item.security);
        if (kind === "open" || kind === "owe") {
            root.join(item.name, kind, "");
            return;
        }
        if (kind === "") {
            root.operation = { kind: "failed", name: item.name,
                error: "This network needs settings that Speshell cannot request. Configure it in NetworkManager first." };
            return;
        }
        root.operation = root.passwordRowName !== item.name ? { kind: "password", name: item.name } : null;
    }

    function connectWithPassword(item, psk) {
        const password = String(psk || "");
        const sae = item.network ? item.network.security === WifiSecurityType.Sae : root.joinKind(item.security) === "sae";
        if (item.network && !root.supportsPsk(item.network.security)) {
            root.operation = { kind: "password", name: item.name, error: "Password entry is not supported for this network type." };
            return;
        }
        if (password.length < (sae ? 1 : 8)) {
            root.operation = { kind: "password", name: item.name,
                error: sae ? "Enter the network password." : "Enter a password with at least 8 characters." };
            return;
        }
        if (item.network)
            root.beginConnection(item.network, password);
        else
            root.join(item.name, root.joinKind(item.security), password);
    }

    // Closes the password prompt, or forgets the last failure.
    function cancelPasswordPrompt() {
        if (root.operation && (root.operation.kind === "password" || root.operation.kind === "failed"))
            root.operation = null;
    }

    function supportsPsk(security) {
        return security === WifiSecurityType.WpaPsk
            || security === WifiSecurityType.Wpa2Psk
            || security === WifiSecurityType.Sae;
    }

    function beginConnection(network, psk) {
        root.operation = { kind: "connect", name: network.name || "Network", network: network };
        if (psk !== "")
            network.connectWithPsk(psk);
        else
            network.connect();
    }

    // nmcli reads the password from stdin.
    function join(ssid, kind, psk) {
        if (root.joiningName !== "")
            return;
        root.operation = { kind: "join", name: ssid, secured: psk !== "" };
        joinProc.input = psk !== "" ? psk + "\n" : "";
        joinProc.command = Shell.script("network.sh", ["join", ssid, kind]);
        joinProc.running = true;
    }

    function joinFailureText(output) {
        if (/Secrets were required|802-1X supplicant|supplicant/i.test(output))
            return "The password was rejected. Check it and try again.";
        if (/No network with SSID|no suitable|not available|could not be found/i.test(output))
            return "The network is no longer in range. Scan again and retry.";
        if (/[Tt]imeout/.test(output))
            return "The network didn't answer in time.";
        const lines = String(output || "").trim().split("\n");
        const last = lines[lines.length - 1].replace(/^Error: /, "").trim();
        return last !== "" ? last : "Could not connect to the network.";
    }

    function finishJoin(exitCode, output) {
        const joined = root.operation;
        if (root.joiningName === "")
            return;
        if (exitCode !== 0)
            root.operation = { kind: joined.secured ? "password" : "failed", name: joined.name,
                error: root.joinFailureText(output) };
        else
            root.operation = null;
        root.refreshList();
    }

    function connectionFailureText(reason) {
        const reasonName = ConnectionFailReason.toString(reason);
        if (reason === ConnectionFailReason.NoSecrets)
            return "A password is required or the saved password was rejected.";
        if (reason === ConnectionFailReason.WifiAuthTimeout || reason === ConnectionFailReason.WifiClientFailed)
            return "Authentication failed. Check the password and try again.";
        if (reason === ConnectionFailReason.WifiNetworkLost)
            return "The network is no longer available. Scan again and retry.";
        return reasonName && reasonName !== "Unknown"
            ? "Connection failed: " + reasonName + "."
            : "Could not connect to the network.";
    }

    function handleConnectionFailed(reason) {
        const connecting = root.operation;
        root.operation = { kind: root.supportsPsk(connecting.network.security) ? "password" : "failed",
            name: connecting.name, error: root.connectionFailureText(reason) };
    }

    onWifiOnChanged: {
        if (!root.wifiOn) {
            root.accessPoints = [];
            root.scannedAtMs = 0;
            if (root.joiningName === "")
                root.operation = null;
        }
    }

    onWifiDeviceChanged: {
        if (!root.wifiDevice) {
            root.accessPoints = [];
            root.scannedAtMs = 0;
        }
    }

    onConnectedWifiChanged: {
        if (root.connectedWifi !== null && root.operationName("connect") !== "")
            root.operation = null;
    }

    Connections {
        target: root.operation && root.operation.kind === "connect" ? root.operation.network : null
        function onConnectionFailed(reason) {
            root.handleConnectionFailed(reason);
        }
    }

    QueuedProcess {
        id: listProc
        command: root.listCommand(false)
        stdout: StdioCollector {
            onStreamFinished: if (root.wifiOn) root.takeList(text, false)
        }
    }

    // One scan: nmcli asks NetworkManager for it and lists what it found once it's done.
    Process {
        id: scanProc
        command: root.listCommand(true)
        stdout: StdioCollector {
            onStreamFinished: if (root.wifiOn) root.takeList(text, true)
        }
    }

    QueuedProcess {
        id: joinProc
        stdout: StdioCollector { id: joinOutput }
        onExited: exitCode => root.finishJoin(exitCode, joinOutput.text)
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.accessPoints.length > 0
        onTriggered: root.nowMs = Date.now()
    }
}
