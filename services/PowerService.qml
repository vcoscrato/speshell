pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Locking, sleep, logout, restart, and power off, and the [Power] mode that sets how
// much power Speshell's motion may use.
Singleton {
    id: root

    // How much power Speshell itself may use, from [Power] mode:
    // - "maximum": theme effects tick with every frame the display shows; recordings
    //   started outside Speshell are noticed within 2 s.
    // - "balanced": theme effects tick at 60 fps, and that check runs every 10 s.
    // - "saver": no theme effects, no interface motion, and that check every minute.
    // Speshell's own tools report their recordings at once in every mode.
    readonly property string mode: ConfigService.settings.power.mode

    readonly property var lockCommand: ConfigService.settings.power.lockCommand
    readonly property string lockerExecutable: String(root.lockCommand[0] || "").trim()
    readonly property bool lockerChecking: !FeatureSupport.commandsKnown
    readonly property bool lockerAvailable: FeatureSupport.hasCommand(root.lockerExecutable)
    property bool busy: false
    property string activeAction: ""
    property string errorMessage: ""

    property string lockerPurpose: ""

    function actionLabel(action) {
        if (action === "lock") return "Lock";
        if (action === "sleep") return "Sleep";
        if (action === "logout") return "Log out";
        if (action === "restart") return "Restart";
        if (action === "poweroff") return "Power off";
        return "Power action";
    }

    function commandError(collector, fallback) {
        var detail = collector && collector.text ? collector.text.trim() : "";
        if (detail === "")
            return fallback;
        var firstLine = detail.split("\n")[0].trim();
        return firstLine !== "" ? firstLine : fallback;
    }

    function fail(message) {
        lockerReadyTimer.stop();
        root.busy = false;
        root.activeAction = "";
        root.lockerPurpose = "";
        root.errorMessage = message;
    }

    function finish() {
        root.busy = false;
        root.activeAction = "";
        root.lockerPurpose = "";
    }

    function startLocker(purpose) {
        if (!root.lockerAvailable) {
            root.fail("Screen locker unavailable. Check [Power] lockCommand.");
            return false;
        }
        if (lockerProcess.running) {
            root.fail("The configured screen locker is already running.");
            return false;
        }

        root.lockerPurpose = purpose;
        lockerProcess.command = root.lockCommand.slice();
        lockerProcess.running = true;
        lockerReadyTimer.restart();
        return true;
    }

    function runAction(action) {
        if (root.busy)
            return false;

        root.errorMessage = "";
        root.busy = true;
        root.activeAction = action;

        if (action === "lock" || action === "sleep") {
            return root.startLocker(action);
        }

        if (action === "logout") {
            // Hyprland's own exit lets hyprshutdown close apps gracefully first.
            actionProcess.command = !HyprlandService.running
                ? ["loginctl", "terminate-session", Quickshell.env("XDG_SESSION_ID") || ""]
                : ["sh", "-c",
                    "if command -v hyprshutdown >/dev/null 2>&1; then exec hyprshutdown; fi; "
                        + "exec hyprctl dispatch \"$1\"",
                    "speshell-logout", HyprlandService.usingLua ? "hl.dsp.exit()" : "exit"];
        }
        else if (action === "restart")
            actionProcess.command = ["systemctl", "reboot"];
        else if (action === "poweroff")
            actionProcess.command = ["systemctl", "poweroff"];
        else {
            root.fail("Unknown power action: " + action);
            return false;
        }

        actionProcess.running = true;
        return true;
    }

    Timer {
        id: lockerReadyTimer
        interval: 750
        repeat: false
        onTriggered: {
            var purpose = root.lockerPurpose;
            if (!lockerProcess.running) {
                root.fail(root.commandError(
                    lockerError,
                    "The configured screen locker exited before securing the session."
                ));
                return;
            }

            if (purpose === "lock") {
                root.finish();
                return;
            }

            if (purpose === "sleep") {
                suspendProcess.running = true;
            }
        }
    }

    Process {
        id: lockerProcess
        running: false
        stderr: StdioCollector { id: lockerError }
        onExited: function(exitCode) {
            if (lockerReadyTimer.running && root.lockerPurpose !== "") {
                root.fail(root.commandError(
                    lockerError,
                    "The configured screen locker exited before securing the session."
                ));
            }
        }
    }

    Process {
        id: suspendProcess
        command: ["systemctl", "suspend"]
        running: false
        stderr: StdioCollector { id: suspendError }
        onExited: function(exitCode) {
            if (root.activeAction !== "sleep")
                return;
            if (exitCode === 0)
                root.finish();
            else
                root.fail(root.commandError(suspendError, "Could not suspend the system."));
        }
    }

    Process {
        id: actionProcess
        running: false
        stderr: StdioCollector { id: actionError }
        onExited: function(exitCode) {
            var action = root.activeAction;
            if (action === "" || action === "lock" || action === "sleep")
                return;
            if (exitCode !== 0) {
                root.fail(root.commandError(
                    actionError,
                    root.actionLabel(action) + " failed."
                ));
                return;
            }
            root.finish();
        }
    }

}
