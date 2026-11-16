pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "Shell.js" as Shell

// The capture and input tools in tools/, for the Tools panel, the bar, and
// `speshell tool`: which are installed, running one, themed and with the [Tools]
// settings, and whether dictation or a recording runs, as activities with their chips'
// actions. That comes from the process list: once at start, for a recording a Relaunch
// finds, and then whenever the tools run `speshell activity refresh`, as they do at
// each start, step, and stop.
Singleton {
    id: root

    readonly property var settings: ConfigService.settings.tools

    // Each tool's script in tools/, and the commands it needs.
    readonly property var catalog: [
        { id: "dictate", label: "Dictation", detail: "Speak, then type it out", iconName: "dictation",
            requires: ["pw-record", "whisper-cli", "wtype", "wl-copy"], types: true },
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

    // What runs now: null, or its activity.
    readonly property var dictation: root.activity("dictation")
    readonly property var recording: root.activity("screen-recording")
    readonly property bool listening: root.dictation !== null && root.dictation.state === "active"

    // A tool asked for before the commands were known.
    property var pendingRun: null
    readonly property var shellNames: ["sh", "bash", "dash", "zsh"]

    function activity(id) {
        return ActivityService.activities.find(activity => activity.id === id) || null;
    }

    // Looks at the processes again.
    function refresh() {
        probeProc.request();
    }

    // The tools' activities in `ps -e -o args=` output. Matching on argv[0] (or the
    // script run by a shell) avoids false positives from editors or pagers that mention
    // a tool.
    function detect(psOutput) {
        let recording = false;
        let dictationToggle = false;
        let dictationRecording = false;
        let dictationTranscribing = false;
        for (const line of String(psOutput || "").split("\n")) {
            const args = line.trim().split(/\s+/);
            let name = args[0].substring(args[0].lastIndexOf("/") + 1);
            if (root.shellNames.indexOf(name) >= 0 && /(^|\/)tools\/dictate$/.test(args[1] || ""))
                name = "dictate";
            const dictationFile = line.indexOf("dictate.wav") >= 0;
            if (name === "wf-recorder")
                recording = true;
            else if (name === "dictate")
                dictationToggle = true;
            else if (name === "pw-record" && dictationFile)
                dictationRecording = true;
            else if (name === "whisper-cli" && dictationFile)
                dictationTranscribing = true;
        }

        const activities = [];
        if (recording) {
            activities.push({
                id: "screen-recording", state: "active", label: "Recording", iconName: "screen-recording",
                tone: "error", actions: [{ id: "stop", label: "Stop and save" }]
            });
        }
        if (dictationTranscribing || (dictationToggle && !dictationRecording)) {
            activities.push({
                id: "dictation", state: "busy", label: "Dictation", detail: "Transcribing…", iconName: "loader",
                tone: "accent"
            });
        } else if (dictationRecording) {
            activities.push({
                id: "dictation", state: "active", label: "Dictation", detail: "Listening…", iconName: "audio-input",
                tone: "accent", actions: [{ id: "finish", label: "Type it out" }, { id: "cancel", label: "Discard" }]
            });
        }
        return activities;
    }

    function tool(id) {
        for (let i = 0; i < root.catalog.length; i++) {
            if (root.catalog[i].id === id)
                return root.catalog[i];
        }
        return null;
    }

    // slurp's #rrggbbaa.
    function selectionColor(color, alpha) {
        function hex(value) {
            const digits = Math.round(value * 255).toString(16);
            return digits.length < 2 ? "0" + digits : digits;
        }
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
            SPESHELL_OCR_LANGUAGES: root.settings.ocrLanguages,
            SPESHELL_DICTATION_LANGUAGES: root.settings.dictationLanguages,
            SPESHELL_DICTATION_VOCABULARY: root.settings.dictationVocabulary
        };
        // Empty leaves the script its default.
        if (root.settings.dictationModel !== "")
            environment.SPESHELL_DICTATION_MODEL = root.settings.dictationModel;
        return environment;
    }

    // Runs tool `id` with `mode` (screenshot and record: "region" or "screen"; dictate:
    // "cancel" or nothing). Dictation types into the focused window, so the bar's
    // dropdowns, which hold the keyboard, close first; so do they with `closePanels`, as
    // from the Tools panel, which shouldn't capture itself. Otherwise they stay, so a
    // screenshot can show them. When one was open, the tool waits for it to go. Returns
    // whether the tool is known and installed.
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

        const command = [Shell.appDir() + "/tools/" + id];
        if (mode)
            command.push(mode);
        const context = { command: command, environment: root.environment() };
        if ((closePanels || id === "dictate") && PanelService.dismiss()) {
            launchTimer.context = context;
            launchTimer.restart();
        } else {
            Quickshell.execDetached(context);
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
            onStreamFinished: ActivityService.setTools(root.detect(text))
        }
    }

    Connections {
        target: ActivityService

        function onActionRequested(activityId, actionId) {
            if (activityId === "screen-recording" && actionId === "stop")
                root.run("record", "");
            else if (activityId === "dictation" && actionId === "finish")
                root.run("dictate", "");
            else if (activityId === "dictation" && actionId === "cancel")
                root.run("dictate", "cancel");
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

        property var context: null

        interval: 300
        onTriggered: Quickshell.execDetached(launchTimer.context)
    }
}
