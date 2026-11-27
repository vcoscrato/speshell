pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "Shell.js" as Shell

// The capture and input tools, for the Tools panel, the bar, and `speshell tool`: which
// are installed, and running one, themed and with the [Tools] settings. Dictation is
// DictationService's; the others are scripts in tools/. What runs shows as activities
// with their chips' actions: dictation's from its service, and a recording from the
// process list, read once at start, for one a Relaunch finds, and then whenever the
// tools run `speshell activity refresh`, as they do at each start, step, and stop.
Singleton {
    id: root

    readonly property var settings: ConfigService.settings.tools

    // Each tool, and the commands it needs.
    readonly property var catalog: [
        { id: "dictate", label: "Dictation", detail: "Speak, then type it out", iconName: "dictation",
            requires: ["pw-record", "whisper-server", "wtype"] },
        { id: "ocr", label: "Copy text", detail: "Read the text in an area", iconName: "text-scan",
            requires: ["grim", "slurp", "tesseract", "wl-copy"] },
        { id: "screenshot", label: "Screenshot", detail: "Save and copy an area", iconName: "screenshot",
            requires: ["grim", "slurp", "wl-copy"], screenMode: true },
        { id: "record", label: "Record", detail: "Record an area with sound", iconName: "record",
            requires: ["wf-recorder", "slurp"], screenMode: true },
        { id: "qr", label: "Scan code", detail: "Copy a QR code or barcode", iconName: "qrcode",
            requires: ["grim", "slurp", "zbarimg", "wl-copy"] },
        { id: "color", label: "Pick color", detail: "Copy a pixel's color", iconName: "color-picker",
            requires: ["hyprpicker", "wl-copy"] }
    ]
    // Every command the tools need, for FeatureSupport to look for.
    readonly property var commands: root.catalog.reduce((all, tool) => all.concat(tool.requires), [])
    readonly property var tools: root.catalog.filter(tool => tool.requires.every(FeatureSupport.hasCommand))

    // A recording running now: null, or its activity.
    readonly property var recording: root.activity("screen-recording")
    // The scripts' activities in the process list, as last read.
    property var detected: []

    // A tool asked for before the commands were known.
    property var pendingRun: null

    function activity(id) {
        return ActivityService.activities.find(activity => activity.id === id) || null;
    }

    // Looks at the processes again.
    function refresh() {
        probeProc.request();
    }

    // The scripts' activities in `ps -e -o args=` output. Matching on argv[0] avoids false
    // positives from editors or pagers that mention a tool.
    function detect(psOutput) {
        const recording = String(psOutput || "").split("\n").some(line => {
            const command = line.trim().split(/\s+/)[0];
            return command.substring(command.lastIndexOf("/") + 1) === "wf-recorder";
        });
        return recording ? [{
            id: "screen-recording", state: "active", label: "Recording", iconName: "screen-recording",
            tone: "error", actions: [{ id: "stop", label: "Stop and save" }]
        }] : [];
    }

    function publish() {
        ActivityService.setTools(root.detected.concat(DictationService.activity ? [DictationService.activity] : []));
    }

    function tool(id) {
        return root.catalog.find(tool => tool.id === id) || null;
    }

    // slurp's #rrggbbaa.
    function selectionColor(color, alpha) {
        const hex = value => Math.round(value * 255).toString(16).padStart(2, "0");
        return "#" + hex(color.r) + hex(color.g) + hex(color.b) + hex(alpha);
    }

    function environment() {
        const theme = Theme;
        const screen = HyprlandService.focusedScreen();
        const environment = {
            SPESHELL_QML_DIR: Shell.appDir(),
            SPESHELL_OUTPUT: screen ? screen.name : "",
            SPESHELL_SELECT_SHADE: root.selectionColor(theme.crust, 0.45),
            SPESHELL_SELECT_BORDER: root.selectionColor(theme.accent, 1),
            SPESHELL_SELECT_FILL: root.selectionColor(theme.accent, theme.tintSubtle),
            SPESHELL_SELECT_BOXES: root.selectionColor(theme.accent, theme.tintStrong),
            SPESHELL_OCR_LANGUAGES: root.settings.ocrLanguages
        };
        return environment;
    }

    // Runs tool `id` with `mode` (screenshot and record: "region" or "screen"; dictate:
    // "cancel" or nothing, which starts, stops, or types). Dictation types into the focused
    // window, so the bar's dropdowns, which hold the keyboard, close first; so do they with
    // `closePanels`, as from the Tools panel, which shouldn't capture itself. Otherwise they
    // stay, so a screenshot can show them. When one was open, the tool waits for it to go.
    // Returns whether the tool is known and installed.
    function run(id, mode, closePanels) {
        if (!FeatureSupport.commandsKnown) {
            root.pendingRun = { id: id, mode: mode, closePanels: closePanels };
            return root.tool(id) !== null;
        }
        const tool = root.tool(id);
        if (!tool)
            return false;
        if (root.tools.indexOf(tool) < 0) {
            const missing = tool.requires.filter(command => !FeatureSupport.hasCommand(command));
            NotificationService.addInternalNotification("tool-" + id, tool.label + " unavailable",
                "Install " + missing.join(", ") + " to use it.", true);
            return false;
        }

        // A keybinding's keys are still down as it runs; the Tools panel's click isn't.
        const action = id === "dictate"
            ? () => mode === "cancel" ? DictationService.cancel() : DictationService.toggle(!closePanels)
            : () => Quickshell.execDetached({
                command: [Shell.appDir() + "/tools/" + id].concat(mode ? [mode] : []),
                environment: root.environment()
            });
        if ((closePanels || id === "dictate") && PanelService.dismiss()) {
            launchTimer.action = action;
            launchTimer.restart();
        } else {
            action();
        }
        return true;
    }

    Component.onCompleted: root.refresh()

    // A request during a probe runs another after it, since that probe may have listed
    // the processes before the change the caller is reporting.
    QueuedProcess {
        id: probeProc
        command: ["ps", "-e", "-o", "args="]
        stdout: StdioCollector {
            onStreamFinished: {
                root.detected = root.detect(text);
                root.publish();
            }
        }
    }

    Connections {
        target: DictationService

        function onActivityChanged() {
            root.publish();
        }
    }

    Connections {
        target: ActivityService

        function onActionRequested(activityId, actionId) {
            if (activityId === "screen-recording" && actionId === "stop")
                root.run("record", "");
            else if (activityId === "dictation" && actionId === "finish")
                DictationService.stop();
            else if (activityId === "dictation" && actionId === "type")
                DictationService.type(false);
            else if (activityId === "dictation" && actionId === "cancel")
                DictationService.cancel();
        }
    }

    // A tool asked for before the commands were known runs once they are.
    Connections {
        target: FeatureSupport

        function onCommandsKnownChanged() {
            if (!FeatureSupport.commandsKnown || !root.pendingRun)
                return;
            const pending = root.pendingRun;
            root.pendingRun = null;
            root.run(pending.id, pending.mode, pending.closePanels);
        }
    }

    // Long enough for a dropdown to leave the screen.
    Timer {
        id: launchTimer

        property var action: null

        interval: 300
        onTriggered: launchTimer.action()
    }
}
