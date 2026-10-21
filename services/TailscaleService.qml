pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Tailscale, through its CLI: whether this device is on the tailnet, its address,
// and the peers online. Switching it needs the user to be tailscaled's operator
// (sudo tailscale set --operator=$USER). A login prints a URL, which opens in the
// browser; the switch waits there until the login finishes.
Singleton {
    id: root

    readonly property bool available: FeatureSupport.hasCommand("tailscale")

    // tailscaled's BackendState: NeedsLogin, NeedsMachineAuth, Stopped, Starting,
    // or Running; "" while tailscaled can't be reached.
    property string backendState: ""
    property string address: ""
    property string tailnet: ""
    property int peerCount: 0
    property int peersOnline: 0
    readonly property bool connected: root.backendState === "Running"
    readonly property bool switching: root.busyAction !== "" || root.backendState === "Starting"

    // "up" or "down" while switching.
    property string busyAction: ""
    // The login page of the switch that's waiting for a login.
    property string authUrl: ""
    property string errorText: ""

    function subtitle() {
        if (root.authUrl !== "")
            return "Finish signing in in your browser";
        if (root.busyAction !== "")
            return root.busyAction === "up" ? "Connecting…" : "Disconnecting…";
        if (root.backendState === "Running") {
            const parts = ["Connected"];
            if (root.address !== "")
                parts.push(root.address);
            if (root.peerCount > 0)
                parts.push(root.peersOnline + " of " + root.peerCount + " online");
            return parts.join(" · ");
        }
        return ({
            NeedsLogin: "Signed out",
            NeedsMachineAuth: "Waiting for admin approval",
            Starting: "Connecting…"
        })[root.backendState] || "Off";
    }

    function refresh() {
        if (root.available && !statusProc.running)
            statusProc.running = true;
    }

    function parseStatus(text) {
        var status;
        try {
            status = JSON.parse(text);
        } catch (error) {
            status = null;
        }
        if (!status) {
            root.backendState = "";
            return;
        }
        var ips = (status.Self && status.Self.TailscaleIPs) || [];
        var peers = Object.values(status.Peer || {});
        root.backendState = status.BackendState || "";
        root.address = ips.find(ip => ip.indexOf(":") === -1) || ips[0] || "";
        root.tailnet = (status.CurrentTailnet && status.CurrentTailnet.Name) || "";
        root.peerCount = peers.length;
        root.peersOnline = peers.filter(peer => peer.Online).length;
    }

    // Signed out, logging in also brings it up.
    function connect() {
        if (root.busyAction !== "")
            return;
        root.busyAction = "up";
        root.errorText = "";
        switchProc.command = ["tailscale", root.backendState === "Stopped" ? "up" : "login"];
        switchProc.running = true;
    }

    function disconnect() {
        if (root.busyAction !== "")
            return;
        root.busyAction = "down";
        root.errorText = "";
        switchProc.command = ["tailscale", "down"];
        switchProc.running = true;
    }

    function cancel() {
        switchProc.cancelled = true;
        switchProc.running = false;
    }

    function openLogin() {
        if (root.authUrl !== "")
            Qt.openUrlExternally(root.authUrl);
    }

    function read(line) {
        switchProc.transcript += line + "\n";
        var match = /https:\/\/\S+/.exec(line);
        if (match && root.authUrl === "") {
            root.authUrl = match[0];
            root.openLogin();
        }
    }

    function finishSwitch(exitCode) {
        var transcript = switchProc.transcript.trim();
        if (exitCode !== 0 && !switchProc.cancelled) {
            if (/access denied/i.test(transcript))
                root.errorText = "Switching Tailscale needs you as its operator: run sudo tailscale set --operator=$USER once.";
            else
                root.errorText = transcript.split("\n").pop() || "Tailscale didn't switch.";
        }
        switchProc.transcript = "";
        switchProc.cancelled = false;
        root.busyAction = "";
        root.authUrl = "";
        root.refresh();
    }

    Process {
        id: statusProc
        command: ["tailscale", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: root.parseStatus(text)
        }
    }

    Process {
        id: switchProc
        property string transcript: ""
        property bool cancelled: false
        stdout: SplitParser {
            onRead: data => root.read(data)
        }
        stderr: SplitParser {
            onRead: data => root.read(data)
        }
        onExited: exitCode => root.finishSwitch(exitCode)
    }

    // tailscaled's notifications: any of them can change the status.
    Process {
        id: watchProc
        running: root.available
        command: ["tailscale", "debug", "watch-ipn"]
        stdout: SplitParser {
            onRead: refreshDebounce.restart()
        }
        onRunningChanged: {
            root.refresh();
            if (!watchProc.running && root.available)
                rewatch.restart();
        }
    }

    // Restarts the watch when tailscaled goes away.
    Timer {
        id: rewatch
        interval: 5000
        onTriggered: watchProc.running = root.available
    }

    Timer {
        id: refreshDebounce
        interval: 500
        onTriggered: root.refresh()
    }
}
