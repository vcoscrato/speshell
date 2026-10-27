pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "../components/Format.js" as Format

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

    // The password prompt, on the row of the network named; the last connection error
    // and the network it's for.
    property string passwordRowName: ""
    property string passwordText: ""
    property string connectErrorName: ""
    property string connectError: ""
    // A saved network connecting through Quickshell, and a new one being joined.
    property var pendingNetwork: null
    property string pendingNetworkName: ""
    readonly property string joiningName: joinProc.running ? joinProc.ssid : ""

    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property var wifiDevice: root.findWifiDevice()
    readonly property var wiredDevice: root.findWiredDevice()
    readonly property var connectedWifi: root.wifiNetworks(function(network) { return network.connected; })[0] || null
    readonly property var connectingNetwork: root.wifiNetworks(function(network) {
        return network.state === ConnectionState.Connecting;
    })[0] || null
    readonly property var displayedNetworks: root.buildDisplayedNetworks()

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

    // The networks Quickshell lists that pass `test`: without its scanner, the saved
    // ones and the connected one.
    function wifiNetworks(test) {
        var result = [];
        var networks = root.wifiDevice ? root.wifiDevice.networks.values : [];
        for (var i = 0; i < networks.length; i++) {
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
        var byName = {};
        var lines = String(text || "").split("\n");
        for (var i = 0; i < lines.length; i++) {
            var fields = lines[i].split(":");
            if (fields.length < 3)
                continue;
            var name = fields.slice(2).join(":").replace(/\\(.)/g, "$1");
            var level = Number(fields[0]) || 0;
            if (name !== "" && (!byName[name] || level > byName[name].signalLevel))
                byName[name] = { name: name, signalLevel: level, security: fields[1], seenMs: now };
        }
        return byName;
    }

    function listOf(byName) {
        var result = [];
        for (var name in byName)
            result.push(byName[name]);
        return result;
    }

    // A scan's list replaces what was there; a look at NetworkManager's list adds to it,
    // since NetworkManager forgets networks a few minutes after a scan.
    function takeList(text, scanned) {
        var now = Date.now();
        var found = root.parseList(text, now);
        if (!scanned) {
            for (var i = 0; i < root.accessPoints.length; i++) {
                var known = root.accessPoints[i];
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
        if (root.wifiDevice && root.wifiOn && !listProc.running && !scanProc.running)
            listProc.running = true;
    }

    function scan() {
        if (root.wifiDevice && root.wifiOn && !scanProc.running)
            scanProc.running = true;
    }

    function listCommand(rescan) {
        var command = ["nmcli", "-t", "-f", "SIGNAL,SECURITY,SSID", "device", "wifi", "list"];
        if (root.wifiDevice && root.wifiDevice.name)
            command.push("ifname", root.wifiDevice.name);
        return command.concat(["--rescan", rescan ? "yes" : "no"]);
    }

    function savedNetwork(name) {
        return root.wifiNetworks(function(network) { return network.known && network.name === name; })[0] || null;
    }

    function buildDisplayedNetworks() {
        var connectedName = root.connectedWifi ? root.connectedWifi.name : "";
        var result = [];
        for (var i = 0; i < root.accessPoints.length; i++) {
            var point = root.accessPoints[i];
            if (point.name === connectedName || root.nowMs - point.seenMs > root.listMaxAgeMs)
                continue;
            var saved = root.savedNetwork(point.name);
            result.push({
                name: point.name,
                signalLevel: point.signalLevel,
                security: point.security,
                network: saved,
                stateChanging: (saved !== null && saved.stateChanging) || root.joiningName === point.name
            });
        }
        return result.sort(function(a, b) {
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
        var kind = root.joinKind(item.security);
        var parts = [];
        if (item.network)
            parts.push("Saved");
        parts.push(kind === "open" || kind === "owe" ? "Open" : "Secured");
        parts.push(item.signalLevel + "%");
        return parts.join(" · ");
    }

    function connectedSubtitle() {
        var network = root.connectedWifi;
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
        var kind = root.joinKind(item.security);
        if (kind === "open" || kind === "owe") {
            root.join(item.name, kind, "");
            return;
        }
        if (kind === "") {
            root.cancelPasswordPrompt();
            root.connectErrorName = item.name;
            root.connectError = "This network needs settings that Speshell cannot request. Configure it in NetworkManager first.";
            return;
        }
        var opening = root.passwordRowName !== item.name;
        root.cancelPasswordPrompt();
        if (opening)
            root.passwordRowName = item.name;
    }

    function connectWithPassword(item, psk) {
        var password = String(psk || "");
        var sae = item.network ? item.network.security === WifiSecurityType.Sae : root.joinKind(item.security) === "sae";
        if (item.network && !root.supportsPsk(item.network.security)) {
            root.connectErrorName = item.name;
            root.connectError = "Password entry is not supported for this network type.";
            return;
        }
        if (password.length < (sae ? 1 : 8)) {
            root.connectErrorName = item.name;
            root.connectError = sae ? "Enter the network password." : "Enter a password with at least 8 characters.";
            return;
        }
        if (item.network)
            root.beginConnection(item.network, password);
        else
            root.join(item.name, root.joinKind(item.security), password);
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

    function join(ssid, kind, psk) {
        if (joinProc.running)
            return;
        root.cancelPasswordPrompt();
        joinProc.ssid = ssid;
        joinProc.secured = psk !== "";
        joinProc.psk = psk;
        joinProc.command = ["bash", "-c", root.joinScript, "speshell-wifi", ssid, kind];
        joinProc.running = true;
    }

    function joinFailureText(output) {
        if (/Secrets were required|802-1X supplicant|supplicant/i.test(output))
            return "The password was rejected. Check it and try again.";
        if (/No network with SSID|no suitable|not available|could not be found/i.test(output))
            return "The network is no longer in range. Scan again and retry.";
        if (/[Tt]imeout/.test(output))
            return "The network didn't answer in time.";
        var lines = String(output || "").trim().split("\n");
        var last = lines[lines.length - 1].replace(/^Error: /, "").trim();
        return last !== "" ? last : "Could not connect to the network.";
    }

    function finishJoin(exitCode, output) {
        if (exitCode !== 0) {
            root.connectErrorName = joinProc.ssid;
            root.connectError = root.joinFailureText(output);
            if (joinProc.secured)
                root.passwordRowName = joinProc.ssid;
        }
        root.refreshList();
    }

    function connectionFailureText(reason) {
        var reasonName = ConnectionFailReason.toString(reason);
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
        root.connectErrorName = root.pendingNetworkName;
        root.connectError = root.connectionFailureText(reason);
        if (root.pendingNetwork && root.supportsPsk(root.pendingNetwork.security))
            root.passwordRowName = root.pendingNetworkName;
        root.pendingNetwork = null;
    }

    // Args: ssid kind; stdin's first line is the password, for wpa-psk and sae.
    readonly property string joinScript: "exec 2>&1\n"
        + "ssid=$1 kind=$2\n"
        + "uuid=$(cat /proc/sys/kernel/random/uuid)\n"
        + "set -- type wifi con-name \"$ssid\" connection.uuid \"$uuid\" ssid \"$ssid\"\n"
        + "[ \"$kind\" = open ] || set -- \"$@\" wifi-sec.key-mgmt \"$kind\"\n"
        + "nmcli connection add \"$@\" >/dev/null || exit 1\n"
        + "if [ \"$kind\" = wpa-psk ] || [ \"$kind\" = sae ]; then\n"
        + "  IFS= read -r psk\n"
        + "  printf 'set 802-11-wireless-security.psk %s\\nsave persistent\\nquit\\n' \"$psk\" | nmcli connection edit uuid \"$uuid\" >/dev/null\n"
        + "fi\n"
        + "nmcli -w 45 connection up uuid \"$uuid\" && exit 0\n"
        + "nmcli connection delete uuid \"$uuid\" >/dev/null\n"
        + "exit 1\n"

    onWifiOnChanged: {
        if (!root.wifiOn) {
            root.accessPoints = [];
            root.scannedAtMs = 0;
            root.pendingNetwork = null;
            root.cancelPasswordPrompt();
        }
    }

    onWifiDeviceChanged: {
        if (!root.wifiDevice) {
            root.accessPoints = [];
            root.scannedAtMs = 0;
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

    Process {
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

    Process {
        id: joinProc
        property string ssid: ""
        property bool secured: false
        property string psk: ""
        stdinEnabled: true
        stdout: StdioCollector { id: joinOutput }
        onStarted: {
            if (joinProc.secured)
                joinProc.write(joinProc.psk + "\n");
            joinProc.psk = "";
            joinProc.stdinEnabled = false;
        }
        onExited: function(exitCode) {
            joinProc.stdinEnabled = true;
            root.finishJoin(exitCode, joinOutput.text);
        }
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.accessPoints.length > 0
        onTriggered: root.nowMs = Date.now()
    }
}
