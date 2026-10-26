pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Locking, sleep, hibernate, logout, restart, and power off, and the power mode that sets how
// much power the system and Speshell's motion may use.
Singleton {
    id: root

    // How much power may be used: [Power] mode, or "saver" on battery with [Power]
    // saverOnBattery, until another mode is picked there.
    // - "maximum": the performance profile (balanced where there is none); theme effects
    //   tick with every frame the display shows; recordings started outside Speshell
    //   are noticed within 2 s.
    // - "balanced": the balanced profile; theme effects tick at 60 fps, and that check
    //   runs every 10 s; on battery, 30 fps and every minute.
    // - "saver": the power-saver profile; no theme effects, no interface motion, and
    //   that check every minute.
    // Speshell's own tools report their recordings at once in every mode.
    readonly property string mode: root.onSaver ? (root.batteryMode || "saver") : root.configuredMode
    readonly property string configuredMode: ConfigService.settings.power.mode
    readonly property bool saverOnBattery: ConfigService.settings.power.saverOnBattery
    readonly property bool onBattery: UPower.onBattery
    readonly property bool onSaver: root.onBattery && root.saverOnBattery
    // A mode picked while saving on battery, until plugged in.
    property string batteryMode: ""

    // Whether the system's power profile follows the mode, through power-profiles-daemon.
    readonly property bool profilesAvailable: FeatureSupport.hasCommand("powerprofilesctl")
    // Reading it connects to the daemon; its profiles arrive a moment later.
    readonly property bool hasPerformanceProfile: PowerProfiles.hasPerformanceProfile

    readonly property var lockCommand: ConfigService.settings.power.lockCommand
    readonly property string lockerExecutable: String(root.lockCommand[0] || "").trim()
    readonly property bool lockerChecking: !FeatureSupport.commandsKnown
    readonly property bool lockerAvailable: FeatureSupport.hasCommand(root.lockerExecutable)
    // Whether the locker Speshell started still runs.
    readonly property bool locked: lockerProcess.running
    // Whether the compositor confirmed the lock, so the locker has drawn on every screen.
    // Only hyprlock says so; sleep waits for it, up to lockSecureTimeout, since sleeping
    // with the locker's first frames still on the GPU can leave the screen frozen on
    // resume (NVIDIA).
    property bool lockSecured: false
    readonly property int lockSecureTimeout: 4000
    property bool busy: false
    property string activeAction: ""
    property string errorMessage: ""

    property string lockerPurpose: ""
    // Whether logind can hibernate: a swap that fits memory, and resume set up.
    property bool canHibernate: false

    function actionLabel(action) {
        if (action === "lock") return "Lock";
        if (action === "sleep") return "Sleep";
        if (action === "hibernate") return "Hibernate";
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

    // Sleep and hibernate lock first, then leave the system to logind.
    function sleeps(action) {
        return action === "sleep" || action === "hibernate";
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
        root.lockSecured = false;
        lockerProcess.command = root.lockCommand.slice();
        lockerProcess.running = true;
        lockerReadyTimer.restart();
        return true;
    }

    // Picked on battery with saverOnBattery, it lasts until plugged in; otherwise it
    // becomes [Power] mode.
    function setMode(mode) {
        if (root.onSaver)
            root.batteryMode = mode;
        else
            ConfigService.setProperty("Power", "mode", mode);
    }

    // Always written: until the daemon answers, PowerProfiles.profile is a placeholder.
    function applyProfile() {
        if (!root.profilesAvailable)
            return;
        PowerProfiles.profile = root.mode === "saver"
            ? PowerProfile.PowerSaver
            : (root.mode === "maximum" && root.hasPerformanceProfile
                ? PowerProfile.Performance
                : PowerProfile.Balanced);
    }

    function runAction(action) {
        if (root.busy)
            return false;

        root.errorMessage = "";
        root.busy = true;
        root.activeAction = action;

        // Already locked, as after idling: sleep needs no second locker.
        if (root.sleeps(action) && lockerProcess.running) {
            sleepProcess.running = true;
            return true;
        }
        if (action === "lock" || root.sleeps(action)) {
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

            if (root.sleeps(purpose)) {
                if (root.lockSecured)
                    sleepProcess.running = true;
                else
                    lockSecureTimer.restart();
            }
        }
    }

    Timer {
        id: lockSecureTimer
        interval: root.lockSecureTimeout
        onTriggered: sleepProcess.running = true
    }

    onLockSecuredChanged: {
        if (root.lockSecured && lockSecureTimer.running) {
            lockSecureTimer.stop();
            sleepProcess.running = true;
        }
    }

    Process {
        id: lockerProcess
        running: false
        stdout: SplitParser {
            // hyprlock's log line once the compositor sends ext-session-lock's locked.
            onRead: function(line) {
                if (line.indexOf("onLockLocked called") >= 0)
                    root.lockSecured = true;
            }
        }
        stderr: StdioCollector { id: lockerError }
        onExited: function(exitCode) {
            root.lockSecured = false;
            lockSecureTimer.stop();
            if (lockerReadyTimer.running && root.lockerPurpose !== "") {
                root.fail(root.commandError(
                    lockerError,
                    "The configured screen locker exited before securing the session."
                ));
            }
        }
    }

    Process {
        id: sleepProcess
        command: ["systemctl", root.activeAction === "hibernate" ? "hibernate" : "suspend"]
        running: false
        stderr: StdioCollector { id: sleepError }
        onExited: function(exitCode) {
            if (!root.sleeps(root.activeAction))
                return;
            if (exitCode === 0)
                root.finish();
            else
                root.fail(root.commandError(sleepError, root.activeAction === "hibernate"
                    ? "Could not hibernate the system." : "Could not suspend the system."));
        }
    }

    // Prints ('yes',) when hibernating works.
    Process {
        running: true
        command: ["gdbus", "call", "--system", "--dest", "org.freedesktop.login1",
            "--object-path", "/org/freedesktop/login1", "--method", "org.freedesktop.login1.Manager.CanHibernate"]
        stdout: StdioCollector {
            onStreamFinished: root.canHibernate = text.indexOf("'yes'") >= 0
        }
    }

    Process {
        id: actionProcess
        running: false
        stderr: StdioCollector { id: actionError }
        onExited: function(exitCode) {
            var action = root.activeAction;
            if (action === "" || action === "lock" || root.sleeps(action))
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

    onOnSaverChanged: root.batteryMode = ""
    onModeChanged: root.applyProfile()
    // At startup: the command probe finishes, then the daemon reports its profiles.
    onProfilesAvailableChanged: root.applyProfile()
    onHasPerformanceProfileChanged: root.applyProfile()
}
