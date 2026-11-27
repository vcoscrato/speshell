pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "Shell.js" as Shell

// Dictation, for its card (core/DictationWindow.qml), its chip in the bar, and the Tools
// panel. dictation.py transcribes the microphone as it's spoken. The finished text can be
// fixed in the card, then typed into the focused window or copied. toggle() runs all of it
// from one key: it starts listening, stops, and types. The helper keeps the speech model
// loaded for [Tools] dictationIdleMinutes after a dictation, so the next one starts at once.
Singleton {
    id: root

    readonly property var settings: ConfigService.settings.tools
    // "idle"; "listening"; "finishing", the last pass over the recording; "ready", with
    // `text` to type or copy; "releasing", while the keys that asked to type it are let go,
    // so none is held down with the typed ones; and "typing".
    property string phase: "idle"
    // While listening: "downloading" or "loading" the speech model first, else "".
    property string preparing: ""
    property real downloadProgress: 0
    // While listening, the words that settled and those still to settle.
    property string settled: ""
    property string pending: ""
    // The finished text, with the card's edits.
    property string text: ""
    // The microphone's level, from 0 to 1, while listening.
    property real level: 0
    // Typing asked for while the last pass runs, done once it ends: { waitForKeys }.
    property var typeRequest: null
    // Commands written once the helper starts.
    property var outbox: []

    // The chip in the bar, and the Tools panel's row: null while idle.
    readonly property var activity: {
        const activity = { id: "dictation", label: "Dictation", tone: "accent", state: "busy", actions: [] };
        if (root.phase === "listening") {
            return Object.assign(activity, {
                state: "active", iconName: "audio-input",
                detail: root.preparing === "downloading" ? "Downloading the speech model…"
                    : root.preparing === "loading" ? "Loading the speech model…" : "Listening…",
                actions: [{ id: "finish", label: "Stop" }, { id: "cancel", label: "Discard" }]
            });
        }
        if (root.phase === "finishing")
            return Object.assign(activity, { iconName: "loader", detail: "Transcribing…" });
        if (root.phase === "ready") {
            return Object.assign(activity, {
                state: "active", iconName: "keyboard", detail: "Ready to type",
                actions: [{ id: "type", label: "Type it out" }, { id: "cancel", label: "Discard" }]
            });
        }
        if (root.phase === "releasing" || root.phase === "typing")
            return Object.assign(activity, { iconName: "loader", detail: "Typing…" });
        return null;
    }

    // From one key: starts, stops, and then types. A key held down then, as a keybinding's
    // are, `waitForKeys` has the typing wait until it's let go.
    function toggle(waitForKeys) {
        if (root.phase === "idle")
            root.start();
        else if (root.phase === "listening")
            root.stop();
        else if (root.phase === "finishing")
            root.typeRequest = { waitForKeys: waitForKeys };
        else if (root.phase === "ready")
            root.type(waitForKeys);
    }

    function start() {
        if (root.phase !== "idle")
            return;
        root.reset();
        root.phase = "listening";
        idleTimer.stop();
        root.send({
            cmd: "start",
            model: root.settings.dictationModel,
            languages: root.settings.dictationLanguages.split(",").filter(code => code !== ""),
            vocabulary: root.settings.dictationVocabulary
        });
    }

    // Stops listening; the text follows from the last pass.
    function stop() {
        if (root.phase !== "listening")
            return;
        root.send({ cmd: "stop" });
        root.phase = "finishing";
        root.level = 0;
    }

    // Throws the dictation away, or stops typing it.
    function cancel() {
        if (root.phase === "idle")
            return;
        if (root.phase === "listening" || root.phase === "finishing")
            root.send({ cmd: "cancel" });
        quietTimer.stop();
        heldTimer.stop();
        typeTimer.stop();
        typeProc.running = false;
        root.end();
    }

    // With `waitForKeys`, the card takes the keyboard to see the keys come up. Typing starts
    // when it does; or, with none coming for a moment, none was down when it took it.
    function type(waitForKeys) {
        if (root.phase !== "ready" || root.text.trim() === "")
            return;
        if (!waitForKeys) {
            root.typeNow();
            return;
        }
        root.phase = "releasing";
        quietTimer.restart();
        heldTimer.restart();
    }

    // From the card while releasing: a key is down, so typing waits for it to come up.
    function keysDown() {
        if (root.phase === "releasing")
            quietTimer.stop();
    }

    // From the card while releasing: the last key down came up.
    function keysUp() {
        if (root.phase === "releasing")
            root.typeNow();
    }

    // Types the text once the card has given the keyboard back to the window it came from.
    function typeNow() {
        if (root.phase !== "ready" && root.phase !== "releasing")
            return;
        quietTimer.stop();
        heldTimer.stop();
        root.phase = "typing";
        typeTimer.restart();
    }

    // Back from waiting on the keys, as when Escape is pressed then.
    function keepText() {
        if (root.phase !== "releasing")
            return;
        quietTimer.stop();
        heldTimer.stop();
        root.phase = "ready";
    }

    function copy() {
        if (root.phase !== "ready")
            return;
        ClipboardService.copyText(root.text);
        root.end();
    }

    function setText(text) {
        if (root.phase === "ready")
            root.text = text;
    }

    function reset() {
        root.preparing = "";
        root.downloadProgress = 0;
        root.settled = "";
        root.pending = "";
        root.text = "";
        root.level = 0;
        root.typeRequest = null;
    }

    function end() {
        root.reset();
        root.phase = "idle";
        idleTimer.restart();
    }

    function send(command) {
        const line = JSON.stringify(command) + "\n";
        if (helper.running) {
            helper.write(line);
        } else {
            root.outbox = root.outbox.concat([line]);
            helper.running = true;
        }
    }

    function receive(line) {
        let message = null;
        try {
            message = JSON.parse(line);
        } catch (error) {
            return;
        }
        const live = root.phase === "listening" || root.phase === "finishing";
        if (message.event === "status" && live) {
            root.preparing = message.status === "listening" ? "" : String(message.status);
            root.downloadProgress = Number(message.progress) || 0;
        } else if (message.event === "level" && root.phase === "listening") {
            root.level = Number(message.value) || 0;
        } else if (message.event === "text" && live) {
            root.settled = String(message.settled || "");
            root.pending = String(message.pending || "");
        } else if (message.event === "final" && root.phase === "finishing") {
            root.finish(String(message.text || ""));
        } else if (message.event === "error" && live) {
            root.fail(String(message.message || ""));
        }
    }

    // Nothing heard ends it quietly.
    function finish(text) {
        if (text === "") {
            root.end();
            return;
        }
        const request = root.typeRequest;
        root.reset();
        root.text = text;
        root.phase = "ready";
        if (request)
            root.type(request.waitForKeys);
    }

    function fail(message) {
        NotificationService.addInternalNotification("dictation", "Dictation failed", message);
        root.end();
    }

    // Stopped by the idle timer, or failed.
    function helperExited() {
        root.outbox = [];
        if (root.phase !== "listening" && root.phase !== "finishing")
            return;
        const lines = helperErrors.text.trim().split("\n");
        root.fail(lines[lines.length - 1] || "The speech helper stopped.");
    }

    Process {
        id: helper
        command: Shell.script("dictation.py", ["serve"])
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root.receive(line)
        }
        stderr: StdioCollector { id: helperErrors }
        onStarted: {
            for (const line of root.outbox)
                helper.write(line);
            root.outbox = [];
        }
        onExited: root.helperExited()
    }

    // Unloads the model once no dictation has run for a while.
    Timer {
        id: idleTimer
        interval: root.settings.dictationIdleMinutes * 60000
        onTriggered: {
            if (root.phase !== "listening" && root.phase !== "finishing")
                helper.running = false;
        }
    }

    Timer {
        id: quietTimer
        interval: 500
        onTriggered: root.typeNow()
    }

    // A key held for long keeps the text rather than type it.
    Timer {
        id: heldTimer
        interval: 10000
        onTriggered: root.keepText()
    }

    // Long enough for the window the card took the keyboard from to have it again.
    Timer {
        id: typeTimer
        interval: 150
        onTriggered: {
            typeProc.input = root.text;
            typeProc.request();
        }
    }

    QueuedProcess {
        id: typeProc
        command: Shell.script("dictation.py", ["type"])
        // Failed, the text stays in the card, to copy.
        onExited: exitCode => {
            if (root.phase !== "typing")
                return;
            if (exitCode === 0) {
                root.end();
                return;
            }
            root.phase = "ready";
            NotificationService.addInternalNotification("dictation", "Dictation failed",
                "Couldn't type the text; copy it from the card.");
        }
    }
}
