pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

// The capture and input tools in tools/, for the Tools panel, the bar, and
// `speshell tool`: which are installed, whether dictation or a recording is running
// (from the activity probe), and running one, themed and with the [Tools] settings.
Singleton {
    id: root

    // [Tools] settings, from the config.
    property string ocrLanguages: "eng"
    property string dictationLanguages: ""
    property string dictationVocabulary: ""
    property string dictationModel: ""

    readonly property string toolsDir: Qt.resolvedUrl("../tools").toString().replace(/^file:\/\//, "")
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
    property var installedCommands: []
    property bool probed: false
    readonly property var tools: root.catalog.filter(function(tool) {
        return tool.requires.every(function(command) { return root.installedCommands.indexOf(command) >= 0; });
    })

    // What runs now, from the activity probe: null, or its activity.
    readonly property var dictation: root.activity("dictation")
    readonly property var recording: root.activity("screen-recording")
    readonly property bool listening: root.dictation !== null && root.dictation.state === "active"

    // A tool asked for before the probe finished.
    property var pendingRun: null

    function activity(id) {
        var activities = ActivityService.activities;
        for (var i = 0; i < activities.length; i++) {
            if (activities[i].id === id)
                return activities[i];
        }
        return null;
    }

    function tool(id) {
        for (var i = 0; i < root.catalog.length; i++) {
            if (root.catalog[i].id === id)
                return root.catalog[i];
        }
        return null;
    }

    // Looks for the tools' commands again, so one installed since shows up.
    function probe() {
        if (probeProc.running)
            return;
        var commands = [];
        root.catalog.forEach(function(tool) {
            tool.requires.forEach(function(command) {
                if (commands.indexOf(command) < 0)
                    commands.push(command);
            });
        });
        probeProc.command = ["sh", "-c", "for c; do command -v \"$c\" >/dev/null 2>&1 && echo \"$c\"; done", "sh"]
            .concat(commands);
        probeProc.running = true;
    }

    // slurp's #rrggbbaa.
    function selectionColor(color, alpha) {
        function hex(value) {
            var digits = Math.round(value * 255).toString(16);
            return digits.length < 2 ? "0" + digits : digits;
        }
        return "#" + hex(color.r) + hex(color.g) + hex(color.b) + hex(alpha);
    }

    function environment() {
        var theme = Theme;
        var screen = HyprlandService.focusedScreen();
        var environment = {
            SPESHELL_QML_DIR: SystemState.appDir.replace(/\/$/, ""),
            SPESHELL_OUTPUT: screen ? screen.name : "",
            SPESHELL_SELECT_SHADE: root.selectionColor(theme.crust, 0.45),
            SPESHELL_SELECT_BORDER: root.selectionColor(theme.accent, 1),
            SPESHELL_SELECT_FILL: root.selectionColor(theme.accent, theme.tintSubtle),
            SPESHELL_SELECT_BOXES: root.selectionColor(theme.accent, theme.tintStrong),
            SPESHELL_OCR_LANGUAGES: root.ocrLanguages,
            SPESHELL_DICTATION_LANGUAGES: root.dictationLanguages,
            SPESHELL_DICTATION_VOCABULARY: root.dictationVocabulary
        };
        // Empty leaves the script its default.
        if (root.dictationModel !== "")
            environment.SPESHELL_DICTATION_MODEL = root.dictationModel;
        return environment;
    }

    // Runs tool `id` with `mode` (screenshot and record: "region" or "screen"; dictate:
    // "cancel" or nothing). The bar's dropdowns close first, so the capture tools don't
    // capture them and dictation types into the focused window; when one was open, the
    // tool waits for it to go. Returns whether the tool is known and installed.
    function run(id, mode) {
        if (!root.probed) {
            root.pendingRun = { id: id, mode: mode };
            return root.tool(id) !== null;
        }
        var tool = root.tool(id);
        if (!tool)
            return false;
        if (root.tools.indexOf(tool) < 0) {
            var missing = tool.requires.filter(function(command) { return root.installedCommands.indexOf(command) < 0; });
            NotificationService.addInternalNotification("tool-" + id, tool.label + " unavailable",
                "Install " + missing.join(", ") + " to use it.", true);
            return false;
        }

        var command = [root.toolsDir + "/" + id];
        if (mode)
            command.push(mode);
        var context = { command: command, environment: root.environment() };
        if (PanelService.dismiss()) {
            launchTimer.context = context;
            launchTimer.restart();
        } else {
            Quickshell.execDetached(context);
        }
        return true;
    }

    Component.onCompleted: root.probe()

    Process {
        id: probeProc
        running: false
        stdout: StdioCollector { id: probeOutput }
        onExited: {
            root.installedCommands = probeOutput.text.split("\n").filter(function(line) { return line !== ""; });
            root.probed = true;
            if (root.pendingRun) {
                var pending = root.pendingRun;
                root.pendingRun = null;
                root.run(pending.id, pending.mode);
            }
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
