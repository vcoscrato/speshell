pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history through cliphist: Speshell runs the wl-paste watcher that stores
// each copy, lists the history with image thumbnails, copies an entry or text back,
// and clears it.
Singleton {
    id: root

    property var history: []
    property bool viewPresented: false
    property bool historyDirty: true
    property bool available: true
    property bool liveUpdatesAvailable: true
    property int maxItems: 40
    property bool refreshQueued: false
    property string feedbackText: ""
    property string feedbackTone: "neutral"
    property string lastCopiedId: ""
    property string pendingCopyId: ""
    readonly property string liveUpdateWarning: "Live clipboard updates are unavailable."
    // Decoded images for thumbnails: private to the user, gone at logout, and pruned to
    // the listed history on every refresh.
    readonly property string thumbnailDir: Quickshell.env("XDG_RUNTIME_DIR")
        ? Quickshell.env("XDG_RUNTIME_DIR") + "/speshell/clipboard"
        : ""

    // cliphist lists binary entries as "[[ binary data 33 KiB png 349x118 ]]".
    function parseEntry(id, preview) {
        var binary = /^\[\[ binary data (.+? [KMG]?i?B)(?: (\w+))?(?: (\d+)x(\d+))? \]\]$/.exec(preview);
        if (binary) {
            var format = binary[2] || "";
            var image = format !== "" && binary[3] !== undefined;
            return {
                "id": id,
                "kind": image ? "image" : "binary",
                "preview": image
                    ? format.toUpperCase() + " image · " + binary[3] + "×" + binary[4] + " · " + binary[1]
                    : "Binary data · " + binary[1],
                "format": format,
                "thumbnail": ""
            };
        }
        var text = preview.replace(/\s+/g, " ").trim();
        return {
            "id": id,
            "kind": /^https?:\/\/\S+$/.test(text) ? "link" : "text",
            "preview": text !== "" ? text : "Whitespace",
            "format": "",
            "thumbnail": ""
        };
    }

    function thumbnailName(entry) {
        return entry.id + "." + entry.format;
    }

    function decodeThumbnails() {
        if (root.thumbnailDir === "" || thumbnailProc.running)
            return;
        var names = [];
        for (var i = 0; i < root.history.length; i++) {
            if (root.history[i].kind === "image")
                names.push(root.thumbnailName(root.history[i]));
        }
        thumbnailProc.command = ["sh", "-c",
            "dir=$1; shift; mkdir -p \"$dir\" && chmod 700 \"$dir\" || exit 1\n"
            + "for name in \"$@\"; do [ -s \"$dir/$name\" ] || cliphist decode \"${name%%.*}\" > \"$dir/$name\"; done\n"
            + "for file in \"$dir\"/*; do [ -e \"$file\" ] || continue\n"
            + "case \" $* \" in *\" ${file##*/} \"*) ;; *) rm -f \"$file\" ;; esac; done",
            "speshell-thumbnails", root.thumbnailDir].concat(names);
        thumbnailProc.running = true;
    }

    function setViewPresented(presented) {
        var next = !!presented;
        if (root.viewPresented === next)
            return;

        root.viewPresented = next;
        if (next) {
            if (!root.liveUpdatesAvailable) {
                root.feedbackText = root.liveUpdateWarning;
                root.feedbackTone = "warning";
            }
            if (root.historyDirty)
                root.refresh();
        } else {
            clipboardChangeDebounce.stop();
        }
    }

    function refresh() {
        if (cliphistListProc.running) {
            root.refreshQueued = true;
            return;
        }

        root.historyDirty = false;
        cliphistListProc.running = true;
    }

    function copyEntry(entry) {
        if (!entry || !entry.id || copyProc.running) {
            return;
        }

        root.pendingCopyId = entry.id;
        root.feedbackText = "Copying…";
        root.feedbackTone = "neutral";
        copyProc.command = [
            "sh", "-c", "cliphist decode \"$1\" | wl-copy", "speshell-copy", String(entry.id)
        ];
        copyProc.running = true;
    }

    function copyText(text) {
        var value = String(text || "");
        if (value === "" || copyProc.running) {
            return;
        }

        root.pendingCopyId = "";
        root.feedbackText = "Copying…";
        root.feedbackTone = "neutral";
        copyProc.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "speshell-copy", value];
        copyProc.running = true;
    }

    function clearHistory() {
        clearProc.running = true;
    }

    Process {
        id: thumbnailProc
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0)
                return;
            root.history = root.history.map(function(entry) {
                return entry.kind === "image" && entry.thumbnail === ""
                    ? Object.assign({}, entry, { "thumbnail": root.thumbnailDir + "/" + root.thumbnailName(entry) })
                    : entry;
            });
        }
    }

    // Own the cliphist writer so clipboard history works without a separately
    // configured session service. The child prints only after storage succeeds.
    Timer {
        id: clipboardChangeDebounce
        interval: 200
        running: false
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        id: watcherRetryTimer
        interval: 30000
        running: false
        repeat: false
        onTriggered: clipboardWatchProc.running = true
    }

    Process {
        id: clipboardWatchProc
        command: [
            "sh",
            "-c",
            "command -v wl-paste >/dev/null 2>&1 "
                + "&& command -v cliphist >/dev/null 2>&1 "
                + "&& exec wl-paste --watch sh -c 'cliphist store && printf \\\"%s\\\\n\\\" \\\"$CLIPBOARD_STATE\\\"'"
        ]
        running: true

        stdout: SplitParser {
            onRead: {
                root.historyDirty = true;
                if (root.viewPresented)
                    clipboardChangeDebounce.restart();
            }
        }

        onStarted: {
            root.liveUpdatesAvailable = true;
            if (root.feedbackText === root.liveUpdateWarning) {
                root.feedbackText = "";
                root.feedbackTone = "neutral";
            }
        }

        onExited: function(exitCode) {
            root.liveUpdatesAvailable = false;
            if (root.viewPresented) {
                root.feedbackText = root.liveUpdateWarning;
                root.feedbackTone = "warning";
            }
            watcherRetryTimer.restart();
        }
    }

    Process {
        id: cliphistListProc
        command: ["sh", "-c", "cliphist list | head -n \"$1\"", "speshell-cliphist", String(root.maxItems)]
        running: false
        stdout: StdioCollector { id: cliphistListOutput }

        onExited: function(exitCode) {
            root.available = exitCode === 0;

            if (exitCode !== 0) {
                root.history = [];
                root.historyDirty = true;
                if (root.viewPresented) {
                    root.feedbackText = "Clipboard history is unavailable.";
                    root.feedbackTone = "warning";
                }
            } else {
                var lines = cliphistListOutput.text.split("\n");
                var newHistory = [];
                // Keep decoded thumbnails, so a refresh doesn't blank the images.
                var thumbnails = {};
                for (var k = 0; k < root.history.length; k++)
                    thumbnails[root.history[k].id] = root.history[k].thumbnail;

                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line === "") continue;

                    var tabIndex = line.indexOf("\t");
                    if (tabIndex <= 0)
                        continue;
                    var entry = root.parseEntry(line.substring(0, tabIndex), line.substring(tabIndex + 1));
                    if (entry.kind === "image")
                        entry.thumbnail = thumbnails[entry.id] || "";
                    newHistory.push(entry);
                }
                root.history = newHistory;
                root.decodeThumbnails();
            }

            if (root.refreshQueued) {
                root.refreshQueued = false;
                root.refresh();
            }
        }
    }

    Process {
        id: copyProc
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) {
                if (root.pendingCopyId !== "") {
                    root.lastCopiedId = root.pendingCopyId;
                    root.refresh();
                }
                root.feedbackText = "Copied to the clipboard.";
                root.feedbackTone = "success";
            } else {
                root.feedbackText = "Copy failed.";
                root.feedbackTone = "error";
            }
            root.pendingCopyId = "";
        }
    }

    Process {
        id: clearProc
        command: ["cliphist", "wipe"]
        running: false
        onExited: function(exitCode) {
            if (exitCode === 0) {
                root.feedbackText = "";
                root.feedbackTone = "neutral";
                root.history = [];
                root.refresh();
            } else {
                root.feedbackText = "Failed to clear history.";
                root.feedbackTone = "error";
            }
        }
    }
}
