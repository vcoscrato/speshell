
import QtQuick
import Quickshell
import Quickshell.Io

// Detects wf-recorder and the dictation tool (tools/dictate) from the process list:
// once at start, for a recording a Relaunch finds, and then whenever Speshell's tools
// run `speshell activity refresh`, as they do at each start, step, and stop.
Scope {
    id: root

    property string lastSignature: ""
    property bool refreshQueued: false
    readonly property var shellNames: ["sh", "bash", "dash", "zsh"]

    function commandName(value) {
        const path = String(value || "");
        return path.substring(path.lastIndexOf("/") + 1);
    }

    // Reads `ps -e -o args=` output. Matching on argv[0] (or the script run by a
    // shell) avoids false positives from editors or pagers that mention a tool.
    function detect(psOutput) {
        let recording = false;
        let dictationToggle = false;
        let dictationRecording = false;
        let dictationTranscribing = false;
        const lines = String(psOutput || "").split("\n");

        for (let i = 0; i < lines.length; i++) {
            const args = lines[i].trim().split(/\s+/);
            let name = root.commandName(args[0]);
            if (root.shellNames.indexOf(name) >= 0 && /(^|\/)tools\/dictate$/.test(args[1] || ""))
                name = "dictate";
            const dictationFile = lines[i].indexOf("dictate.wav") >= 0;

            if (name === "wf-recorder")
                recording = true;
            else if (name === "dictate")
                dictationToggle = true;
            else if (name === "pw-record" && dictationFile)
                dictationRecording = true;
            else if (name === "whisper-cli" && dictationFile)
                dictationTranscribing = true;
        }

        const entries = [];
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
        const entries = root.detect(value);
        const signature = entries.map(entry => entry.id + ":" + entry.state).join(",");
        if (signature === root.lastSignature)
            return;
        root.lastSignature = signature;
        ActivityService.replaceProvider("process", entries);
    }

    // A request during a probe runs another one after it, since that probe may
    // have listed processes before the change the caller is reporting.
    function refresh() {
        if (probeProc.running)
            root.refreshQueued = true;
        else
            probeProc.running = true;
    }

    Component.onCompleted: root.refresh()
    Component.onDestruction: ActivityService.clearProvider("process")

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
