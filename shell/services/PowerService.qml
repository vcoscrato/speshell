pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "Shell.js" as Shell

// Locking, sleep, hibernate, logout, restart, and power off, and the power mode that sets how
// much power the system and Speshell's motion may use.
Singleton {
    id: root

    // How much power may be used: [Power] mode, or "saver" on battery with [Power]
    // saverOnBattery, until another mode is picked there.
    // - "maximum": the performance profile (balanced where there is none); theme effects
    //   tick with every frame the display shows.
    // - "balanced": the balanced profile; theme effects tick at 60 fps, 30 on battery.
    // - "saver": the power-saver profile; no theme effects and no interface motion.
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

    // Speshell's version: the checkout's revision, or the package's.
    property string appVersion: "Unknown"
    property bool relaunching: false
    readonly property bool canRelaunch: !root.relaunching && !ConfigService.writing

    // The action running, or "".
    property string activeAction: ""
    readonly property bool busy: root.activeAction !== ""
    property string errorMessage: ""

    // What each action runs, and what its failure says when the command doesn't. Sleep
    // and hibernate leave locking to LockService, which logind waits on.
    readonly property var commands: ({
        sleep: { command: ["systemctl", "suspend"], failure: "Could not suspend the system." },
        hibernate: { command: ["systemctl", "hibernate"], failure: "Could not hibernate the system." },
        restart: { command: ["systemctl", "reboot"], failure: "Could not restart the system." },
        poweroff: { command: ["systemctl", "poweroff"], failure: "Could not power off the system." }
    })

    function commandError(collector, fallback) {
        const detail = collector && collector.text ? collector.text.trim() : "";
        if (detail === "")
            return fallback;
        const firstLine = detail.split("\n")[0].trim();
        return firstLine !== "" ? firstLine : fallback;
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

        if (action === "lock") {
            LockService.lock();
            return true;
        }
        // Under Hyprland, hyprshutdown closes the apps gracefully before it exits.
        if (action === "logout" && HyprlandService.running && !FeatureSupport.hasCommand("hyprshutdown")) {
            HyprlandService.dispatch("hl.dsp.exit()", "exit");
            return true;
        }

        const entry = action === "logout"
            ? { command: HyprlandService.running ? ["hyprshutdown"]
                    : ["loginctl", "terminate-session", Quickshell.env("XDG_SESSION_ID") || ""],
                failure: "Could not log out." }
            : root.commands[action];
        if (!entry) {
            root.errorMessage = "Unknown power action: " + action;
            return false;
        }
        root.activeAction = action;
        actionProcess.failure = entry.failure;
        actionProcess.command = entry.command;
        actionProcess.running = true;
        return true;
    }

    Process {
        id: actionProcess

        property string failure: ""

        running: false
        stderr: StdioCollector { id: actionError }
        onExited: exitCode => {
            root.activeAction = "";
            if (exitCode !== 0)
                root.errorMessage = root.commandError(actionError, actionProcess.failure);
        }
    }

    // Starts a new Speshell once this process has exited; notes are saved first.
    function relaunch() {
        if (!root.canRelaunch)
            return;
        root.relaunching = true;
        NotesService.flush(true);
        const shellPath = Quickshell.shellDir || Quickshell.shellRoot;
        Quickshell.execDetached(Shell.script("system.sh", ["relaunch", String(Quickshell.processId)]
            .concat(shellPath !== "" ? ["-p", shellPath] : [])));
        Qt.quit();
    }

    Process {
        running: true
        command: Shell.script("system.sh", ["version", Shell.appDir()])
        stdout: StdioCollector {
            onStreamFinished: root.appVersion = text.trim() || "Unknown"
        }
    }

    onOnSaverChanged: root.batteryMode = ""
    onModeChanged: root.applyProfile()
    // At startup: the command probe finishes, then the daemon reports its profiles.
    onProfilesAvailableChanged: root.applyProfile()
    onHasPerformanceProfileChanged: root.applyProfile()
}
