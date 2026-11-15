pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Shell.js" as Shell

// Clipboard history through cliphist: Speshell runs the wl-paste watcher that stores
// each copy, lists the history with image thumbnails, copies an entry or text back,
// and clears it. clipboard.sh does the cliphist side.
Singleton {
    id: root

    property var history: []
    readonly property int maxItems: 40
    // Whether the clipboard panel shows, and whether the history changed since it did.
    property bool viewPresented: false
    property bool historyDirty: true
    property bool refreshQueued: false
    // The copy running, or null: { id }, an entry's, or "" for text.
    property var copying: null
    property string feedbackText: ""
    property string feedbackTone: "neutral"
    property string lastCopiedId: ""

    readonly property bool installed: FeatureSupport.hasCommand("cliphist") && FeatureSupport.hasCommand("wl-paste")
    // Assumed until the first look for commands says otherwise.
    readonly property bool available: root.installed || FeatureSupport.probedCommands === ""
    readonly property bool watching: watchProc.running
    // Decoded images for thumbnails: private to the user, gone at logout, and pruned to
    // the listed history on every refresh.
    readonly property string thumbnailDir: Quickshell.env("XDG_RUNTIME_DIR")
        ? Quickshell.env("XDG_RUNTIME_DIR") + "/speshell/clipboard"
        : ""

    onInstalledChanged: root.watch()
    Component.onCompleted: root.watch()

    // cliphist lists binary entries as "[[ binary data 33 KiB png 349x118 ]]".
    function parseEntry(id, preview) {
        const binary = /^\[\[ binary data (.+? [KMG]?i?B)(?: (\w+))?(?: (\d+)x(\d+))? \]\]$/.exec(preview);
        if (binary) {
            const format = binary[2] || "";
            const image = format !== "" && binary[3] !== undefined;
            return {
                id: id,
                kind: image ? "image" : "binary",
                preview: image
                    ? format.toUpperCase() + " image · " + binary[3] + "×" + binary[4] + " · " + binary[1]
                    : "Binary data · " + binary[1],
                format: format,
                thumbnail: ""
            };
        }
        const text = preview.replace(/\s+/g, " ").trim();
        return {
            id: id,
            kind: /^https?:\/\/\S+$/.test(text) ? "link" : "text",
            preview: text !== "" ? text : "Whitespace",
            format: "",
            thumbnail: ""
        };
    }

    function thumbnailName(entry) {
        return entry.id + "." + entry.format;
    }

    function watch() {
        if (root.installed && !watchProc.running)
            watchProc.running = true;
    }

    function warnUnwatched() {
        if (root.viewPresented && root.installed && !root.watching)
            root.setFeedback("Live clipboard updates are unavailable.", "warning");
    }

    function setFeedback(text, tone) {
        root.feedbackText = text;
        root.feedbackTone = tone;
    }

    function setViewPresented(presented) {
        if (root.viewPresented === presented)
            return;
        root.viewPresented = presented;
        if (!presented) {
            changeDebounce.stop();
            return;
        }
        root.warnUnwatched();
        if (root.historyDirty)
            root.refresh();
    }

    function refresh() {
        if (!root.installed)
            return;
        if (listProc.running) {
            root.refreshQueued = true;
            return;
        }
        root.historyDirty = false;
        listProc.running = true;
    }

    function finishList(exitCode, output) {
        if (exitCode !== 0) {
            root.history = [];
            root.historyDirty = true;
            if (root.viewPresented)
                root.setFeedback("Clipboard history is unavailable.", "warning");
        } else {
            // Keep decoded thumbnails, so a refresh doesn't blank the images.
            const thumbnails = {};
            root.history.forEach(entry => thumbnails[entry.id] = entry.thumbnail);
            root.history = output.split("\n").map(line => line.trim()).filter(line => line.indexOf("\t") > 0)
                .map(line => {
                    const tab = line.indexOf("\t");
                    const entry = root.parseEntry(line.substring(0, tab), line.substring(tab + 1));
                    if (entry.kind === "image")
                        entry.thumbnail = thumbnails[entry.id] || "";
                    return entry;
                });
            root.decodeThumbnails();
        }
        if (root.refreshQueued) {
            root.refreshQueued = false;
            root.refresh();
        }
    }

    // Decodes the listed images; a list that changes meanwhile decodes again after.
    function decodeThumbnails() {
        if (root.thumbnailDir === "")
            return;
        if (thumbnailProc.running) {
            thumbnailProc.queued = true;
            return;
        }
        const names = root.history.filter(entry => entry.kind === "image").map(root.thumbnailName);
        thumbnailProc.command = Shell.script("clipboard.sh", ["thumbnails", root.thumbnailDir].concat(names));
        thumbnailProc.running = true;
    }

    // The names clipboard.sh decoded, of the images listed when it started.
    function finishThumbnails(output) {
        const decoded = output.split("\n").filter(name => name !== "");
        root.history = root.history.map(entry => entry.kind === "image" && decoded.includes(root.thumbnailName(entry))
            ? Object.assign({}, entry, { thumbnail: root.thumbnailDir + "/" + root.thumbnailName(entry) })
            : entry);
        if (thumbnailProc.queued) {
            thumbnailProc.queued = false;
            root.decodeThumbnails();
        }
    }

    function copy(id, command, input) {
        if (root.copying)
            return;
        root.copying = { id: id };
        root.setFeedback("Copying…", "neutral");
        copyProc.input = input;
        copyProc.command = command;
        copyProc.running = true;
    }

    function copyEntry(entry) {
        if (entry && entry.id)
            root.copy(entry.id, Shell.script("clipboard.sh", ["copy", String(entry.id)]), "");
    }

    // Through stdin, where a large text fits.
    function copyText(text) {
        const value = String(text || "");
        if (value !== "")
            root.copy("", ["wl-copy"], value);
    }

    function finishCopy(exitCode) {
        const id = root.copying ? root.copying.id : "";
        root.copying = null;
        if (exitCode !== 0) {
            root.setFeedback("Copy failed.", "error");
            return;
        }
        root.setFeedback("Copied to the clipboard.", "success");
        if (id !== "") {
            root.lastCopiedId = id;
            root.refresh();
        }
    }

    function clearHistory() {
        clearProc.running = true;
    }

    // Each copy refreshes the open panel, once the copies stop for a moment.
    Timer {
        id: changeDebounce
        interval: 200
        onTriggered: root.refresh()
    }

    // A watcher that stopped, as when the compositor restarted, starts again.
    Timer {
        id: watchRetry
        interval: 30000
        onTriggered: root.watch()
    }

    // Speshell owns the cliphist writer, so the history needs no session service of
    // its own. It prints a line once each copy is stored.
    Process {
        id: watchProc
        command: Shell.script("clipboard.sh", ["watch"])
        stdout: SplitParser {
            onRead: {
                root.historyDirty = true;
                if (root.viewPresented)
                    changeDebounce.restart();
            }
        }
        onStarted: {
            if (root.feedbackTone === "warning")
                root.setFeedback("", "neutral");
        }
        onExited: {
            root.warnUnwatched();
            if (root.installed)
                watchRetry.restart();
        }
    }

    Process {
        id: listProc
        command: Shell.script("clipboard.sh", ["list", String(root.maxItems)])
        stdout: StdioCollector { id: listOutput }
        onExited: exitCode => root.finishList(exitCode, listOutput.text)
    }

    Process {
        id: thumbnailProc
        property bool queued: false
        stdout: StdioCollector { id: thumbnailOutput }
        onExited: root.finishThumbnails(thumbnailOutput.text)
    }

    Process {
        id: copyProc
        property string input: ""
        stdinEnabled: true
        onStarted: {
            if (copyProc.input !== "")
                copyProc.write(copyProc.input);
            copyProc.input = "";
            // Closes stdin, the end of the text.
            copyProc.stdinEnabled = false;
        }
        onExited: exitCode => {
            copyProc.stdinEnabled = true;
            root.finishCopy(exitCode);
        }
    }

    Process {
        id: clearProc
        command: ["cliphist", "wipe"]
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.setFeedback("Failed to clear history.", "error");
                return;
            }
            root.setFeedback("", "neutral");
            root.history = [];
            root.refresh();
        }
    }
}
