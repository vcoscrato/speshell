pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // How much power Speshell itself may use, from [Power] mode:
    // - "maximum": theme effects tick with every frame the display shows; recordings
    //   started outside Speshell are noticed within 2 s.
    // - "balanced": theme effects tick at 60 fps, and that check runs every 10 s.
    // - "saver": no theme effects, no interface motion, and that check every minute.
    // Speshell's own tools report their recordings at once in every mode.
    property string mode: "balanced"

    property var lockCommand: ["hyprlock"]
    property bool lockerAvailable: false
    property bool lockerChecking: true
    property bool busy: false
    property string activeAction: ""
    property string errorMessage: ""

    property string lockerPurpose: ""
    property string lockerProbeTarget: ""
    property string checkedLockerExecutable: ""

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

    function probeLocker() {
        var command = root.lockCommand || [];
        var executable = command.length > 0 ? String(command[0]).trim() : "";

        if (executable === "") {
            root.checkedLockerExecutable = "";
            root.lockerAvailable = false;
            root.lockerChecking = false;
            return;
        }

        if (!lockerProbe.running && root.checkedLockerExecutable === executable) {
            root.lockerChecking = false;
            return;
        }

        root.lockerChecking = true;
        if (root.checkedLockerExecutable !== executable)
            root.lockerAvailable = false;

        // A running probe checks again for this one when it ends.
        if (lockerProbe.running)
            return;

        root.lockerProbeTarget = executable;
        lockerProbe.command = ["which", executable];
        lockerProbe.running = true;
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

    onLockCommandChanged: probeLocker()

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
        id: lockerProbe
        running: false
        onExited: function(exitCode) {
            var completedTarget = root.lockerProbeTarget;
            var command = root.lockCommand || [];
            var desiredTarget = command.length > 0 ? String(command[0]).trim() : "";
            root.lockerProbeTarget = "";

            if (completedTarget === desiredTarget) {
                root.checkedLockerExecutable = completedTarget;
                root.lockerAvailable = exitCode === 0;
            }

            if (desiredTarget !== completedTarget)
                Qt.callLater(root.probeLocker);
            else
                root.lockerChecking = false;
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

    Component.onCompleted: probeLocker()
}
