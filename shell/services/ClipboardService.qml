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
    // The copy running, or null: { id }, an entry's, or "" for text.
    property var copying: null
    // What the last action says, as { text, tone }.
    property var feedback: ({ text: "", tone: "neutral" })
    property string lastCopiedId: ""
    // The ids remove() dropped that wait for the delete running to end.
    property var deleting: []

    readonly property bool installed: FeatureSupport.hasCommand("cliphist") && FeatureSupport.hasCommand("wl-paste")
    // Assumed until the first look for commands says otherwise.
    readonly property bool available: root.installed || FeatureSupport.probedCommands === ""
    readonly property bool watching: watchProc.running
    // Decoded images for thumbnails: private to the user, gone at logout, and pruned to
    // the listed history on every refresh.
    readonly property string thumbnailDir: Quickshell.env("XDG_RUNTIME_DIR")
        ? Quickshell.env("XDG_RUNTIME_DIR") + "/speshell/clipboard"
        : ""

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

    function warnUnwatched() {
        if (root.viewPresented && root.installed && !root.watching)
            root.setFeedback("Live clipboard updates are unavailable.", "warning");
    }

    function setFeedback(text, tone) {
        root.feedback = { text: text, tone: tone };
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
        root.historyDirty = false;
        listProc.request();
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
    }

    // Decodes the listed images.
    function decodeThumbnails() {
        if (root.thumbnailDir === "")
            return;
        const names = root.history.filter(entry => entry.kind === "image").map(root.thumbnailName);
        thumbnailProc.command = Shell.script("clipboard.sh", ["thumbnails", root.thumbnailDir].concat(names));
        thumbnailProc.request();
    }

    // The names clipboard.sh decoded, of the images listed when it started.
    function finishThumbnails(output) {
        const decoded = output.split("\n").filter(name => name !== "");
        root.history = root.history.map(entry => entry.kind === "image" && decoded.includes(root.thumbnailName(entry))
            ? Object.assign({}, entry, { thumbnail: root.thumbnailDir + "/" + root.thumbnailName(entry) })
            : entry);
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

    // Through stdin, where a large text fits, and through the script, so a missing
    // wl-copy fails as a copy rather than never starting.
    function copyText(text) {
        const value = String(text || "");
        if (value !== "")
            root.copy("", Shell.script("clipboard.sh", ["text"]), value);
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

    // Drops one entry from the history at once, and from cliphist's after.
    function remove(entry) {
        root.history = root.history.filter(other => other.id !== entry.id);
        root.deleting = root.deleting.concat([entry.id]);
        root.deleteNext();
    }

    // Deletes the entries gathered since the last delete started.
    function deleteNext() {
        if (deleteProc.running || root.deleting.length === 0)
            return;
        deleteProc.command = Shell.script("clipboard.sh", ["delete"].concat(root.deleting));
        root.deleting = [];
        deleteProc.running = true;
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

    // Speshell owns the cliphist writer, so the history needs no session service of
    // its own. It prints a line once each copy is stored, and starts again when it
    // stops, as when the compositor restarted.
    Watcher {
        id: watchProc
        watching: root.installed
        command: Shell.script("clipboard.sh", ["watch"])
        stdout: SplitParser {
            onRead: {
                root.historyDirty = true;
                if (root.viewPresented)
                    changeDebounce.restart();
            }
        }
        onStarted: {
            if (root.feedback.tone === "warning")
                root.setFeedback("", "neutral");
        }
        onExited: root.warnUnwatched()
    }

    // A refresh during a list lists again after it.
    QueuedProcess {
        id: listProc
        command: Shell.script("clipboard.sh", ["list", String(root.maxItems)])
        stdout: StdioCollector { id: listOutput }
        onExited: exitCode => root.finishList(exitCode, listOutput.text)
    }

    // A list that changes while it decodes decodes again after.
    QueuedProcess {
        id: thumbnailProc
        stdout: StdioCollector { id: thumbnailOutput }
        onExited: root.finishThumbnails(thumbnailOutput.text)
    }

    QueuedProcess {
        id: copyProc
        onExited: exitCode => root.finishCopy(exitCode)
    }

    Process {
        id: deleteProc
        onExited: exitCode => {
            if (exitCode !== 0)
                root.setFeedback("Failed to delete from history.", "error");
            if (root.deleting.length > 0)
                Qt.callLater(root.deleteNext);
            else
                root.refresh();
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
