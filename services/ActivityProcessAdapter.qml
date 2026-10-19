
import QtQuick
import Quickshell
import Quickshell.Io

// Detects wf-recorder and the dictation tool (tools/dictate). Polling only runs
// when one of them is installed, and slows down while nothing is active and as the
// power mode saves more. Speshell's tools run `speshell activity refresh` as they
// start and stop, which probes right away, so polling only catches the rest.
Scope {
    id: root

    property bool toolsAvailable: false
    property string lastSignature: ""
    property bool anyActive: false
    property bool refreshQueued: false
    readonly property var shellNames: ["sh", "bash", "dash", "zsh"]

    function commandName(value) {
        var path = String(value || "");
        return path.substring(path.lastIndexOf("/") + 1);
    }

    // Reads `ps -e -o args=` output. Matching on argv[0] (or the script run by a
    // shell) avoids false positives from editors or pagers that mention a tool.
    function detect(psOutput) {
        var recording = false;
        var dictationToggle = false;
        var dictationRecording = false;
        var dictationTranscribing = false;
        var lines = String(psOutput || "").split("\n");

        for (var i = 0; i < lines.length; i++) {
            var args = lines[i].trim().split(/\s+/);
            var name = root.commandName(args[0]);
            if (root.shellNames.indexOf(name) >= 0 && /(^|\/)tools\/dictate$/.test(args[1] || ""))
                name = "dictate";
            var dictationFile = lines[i].indexOf("dictate.wav") >= 0;

            if (name === "wf-recorder")
                recording = true;
            else if (name === "dictate")
                dictationToggle = true;
            else if (name === "pw-record" && dictationFile)
                dictationRecording = true;
            else if (name === "whisper-cli" && dictationFile)
                dictationTranscribing = true;
        }

        var entries = [];
        if (recording) {
            entries.push({
                id: "screen-recording",
                state: "active",
                label: "Recording",
                iconName: "screen-recording",
                tone: "error",
                priority: 10,
                sortOrder: 0,
                actions: [{ id: "stop", label: "Stop and save" }]
            });
        }
        if (dictationTranscribing || (dictationToggle && !dictationRecording)) {
            entries.push({
                id: "dictation",
                state: "busy",
                label: "Dictation",
                detail: "Transcribing…",
                iconName: "loader",
                tone: "accent",
                priority: 10,
                sortOrder: 1
            });
        } else if (dictationRecording) {
            entries.push({
                id: "dictation",
                state: "active",
                label: "Dictation",
                detail: "Listening…",
                iconName: "audio-input",
                tone: "accent",
                priority: 10,
                sortOrder: 1,
                actions: [{ id: "finish", label: "Type it out" }, { id: "cancel", label: "Discard" }]
            });
        }
        return entries;
    }

    function applyProbeOutput(value) {
        var entries = root.detect(value);
        var signature = entries.map(function(entry) { return entry.id + ":" + entry.state; }).join(",");
        root.anyActive = entries.length > 0;
        if (signature === root.lastSignature)
            return;
        root.lastSignature = signature;
        ActivityService.replaceProvider("process", entries);
    }

    // A request during a probe runs another one after it, since that probe may
    // have listed processes before the change the caller is reporting.
    function refresh() {
        if (!root.toolsAvailable)
            return;
        if (probeProc.running)
            root.refreshQueued = true;
        else
            probeProc.running = true;
    }

    Component.onDestruction: ActivityService.clearProvider("process")

    Process {
        running: true
        command: [
            "sh", "-c",
            "command -v wf-recorder >/dev/null 2>&1 || command -v whisper-cli >/dev/null 2>&1"
        ]
        onExited: function(exitCode) {
            root.toolsAvailable = exitCode === 0;
            root.refresh();
        }
    }

    // Seconds between probes, while something is active and while nothing is.
    readonly property var pollSeconds: ({ maximum: [1, 2], balanced: [2, 10], saver: [10, 60] })[PowerService.mode]
        || [2, 10]

    Timer {
        interval: 1000 * root.pollSeconds[root.anyActive ? 0 : 1]
        repeat: true
        running: root.toolsAvailable
        onTriggered: root.refresh()
    }

    Process {
        id: probeProc

        running: false
        command: ["ps", "-e", "-o", "args="]
        stdout: StdioCollector { id: probeOutput }
        onExited: {
            root.applyProbeOutput(probeOutput.text);
            if (root.refreshQueued) {
                root.refreshQueued = false;
                Qt.callLater(root.refresh);
            }
        }
    }

    Connections {
        target: ActivityService

        function onActionRequested(provider, activityId, actionId) {
            if (provider !== "process")
                return;
            if (activityId === "screen-recording" && actionId === "stop")
                Quickshell.execDetached(["pkill", "-SIGINT", "-x", "wf-recorder"]);
            else if (activityId === "dictation" && actionId === "finish")
                ToolsService.run("dictate", "");
            else if (activityId === "dictation" && actionId === "cancel")
                ToolsService.run("dictate", "cancel");
        }
    }
}
