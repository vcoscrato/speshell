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

    readonly property bool locked: LockService.locked
    property bool busy: false
    property string activeAction: ""
    property string errorMessage: ""

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
        secureTimer.stop();
        root.busy = false;
        root.activeAction = "";
        root.errorMessage = message;
    }

    function finish() {
        root.busy = false;
        root.activeAction = "";
    }

    // Sleeps once every screen shows the lock.
    function sleepWhenSecure() {
        if (LockService.secure)
            sleepProcess.running = true;
        else
            secureTimer.restart();
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

        if (action === "lock") {
            LockService.lock();
            root.finish();
            return true;
        }
        if (root.sleeps(action)) {
            LockService.lock();
            root.sleepWhenSecure();
            return true;
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

    // How long the compositor may take to cover the screens before sleep gives up.
    Timer {
        id: secureTimer
        interval: 3000
        onTriggered: root.fail("The screen did not lock, so the system stayed awake.")
    }

    Connections {
        target: LockService

        function onSecureChanged() {
            if (LockService.secure && secureTimer.running) {
                secureTimer.stop();
                sleepProcess.running = true;
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
