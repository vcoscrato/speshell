pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Tailscale, through its CLI: whether this device is on the tailnet. Switching it needs
// the user to be tailscaled's operator (sudo tailscale set --operator=$USER). A login
// prints a URL, which opens in the browser; the switch waits there until the login
// finishes.
Singleton {
    id: root

    readonly property bool available: FeatureSupport.hasCommand("tailscale")
    // Whether tailscaled answered the last look. While it doesn't, as when it is off,
    // nothing watches it; a look when the network panel opens or the network changes
    // finds it again.
    property bool daemonUp: true

    // tailscaled's BackendState: NeedsLogin, NeedsMachineAuth, Stopped, Starting,
    // or Running; "" while tailscaled can't be reached.
    property string backendState: ""
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
        return ({
            Running: "Connected",
            NeedsLogin: "Signed out",
            NeedsMachineAuth: "Waiting for admin approval",
            Starting: "Connecting…"
        })[root.backendState] || "Off";
    }

    function refresh() {
        if (root.available)
            statusProc.request();
    }

    function parseStatus(text) {
        let status;
        try {
            status = JSON.parse(text);
        } catch (error) {
            status = null;
        }
        root.daemonUp = status !== null;
        root.backendState = (status && status.BackendState) || "";
    }

    // Brings up the current profile, and prints its login page when it's signed out.
    // Never "tailscale login": that switches tailscaled to a new, empty profile, which
    // has no operator.
    function connect() {
        if (root.busyAction !== "")
            return;
        root.busyAction = "up";
        root.errorText = "";
        switchProc.command = ["tailscale", "up"];
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
        const match = /https:\/\/\S+/.exec(line);
        if (match && root.authUrl === "") {
            root.authUrl = match[0];
            root.openLogin();
        }
    }

    function finishSwitch(exitCode) {
        const transcript = switchProc.transcript.trim();
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

    QueuedProcess {
        id: statusProc
        command: ["tailscale", "status", "--json", "--peers=false"]
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

    // tailscaled's notifications: any of them can change the status. It exits when
    // tailscaled goes away, and the look then tells whether to start it again.
    Watcher {
        watching: root.available && root.daemonUp
        command: ["tailscale", "debug", "watch-ipn"]
        stdout: SplitParser {
            onRead: refreshDebounce.restart()
        }
        onRunningChanged: root.refresh()
    }

    Connections {
        target: NetworkService

        function onConnectedWifiChanged() {
            if (!root.daemonUp)
                root.refresh();
        }
        function onWiredDeviceChanged() {
            if (!root.daemonUp)
                root.refresh();
        }
    }

    Timer {
        id: refreshDebounce
        interval: 500
        onTriggered: root.refresh()
    }
}
