pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var noteList: []
    property string currentNote: ""
    property string text: ""
    property string savedText: ""
    property string writeText: ""
    property string writeNote: ""
    property string loadTarget: ""
    property string errorText: ""
    property bool initialized: false
    property bool initializing: false
    property bool bootstrapped: false
    property bool loaded: false
    property bool loading: false
    property bool dirty: false
    property bool saving: false
    property bool saveQueued: false
    property bool mutating: false
    property string mutationKind: ""
    property string mutationTarget: ""
    property string mutationNextNote: ""
    property var mutationNextList: []
    property int mutationOriginalIndex: -1
    property string pendingDeleteNote: ""
    property int pendingDeleteIndex: -1
    property string bootstrapDataDir: ""
    property bool externalReload: false

    readonly property string notesDir: ConfigService.dataDir !== ""
        ? ConfigService.dataDir + "/notes"
        : ""
    readonly property string activeNotePath: root.notesDir !== ""
        ? root.notesDir + "/.active"
        : ""
    readonly property string trashDir: root.notesDir !== ""
        ? root.notesDir + "/.trash"
        : ""
    readonly property string notesPath: root.resolveNotePath(root.currentNote)
    readonly property bool managementEnabled: root.initialized
        && root.loaded
        && !root.loading
        && !root.mutating

    function resolveNotePath(name) {
        if (root.notesDir === "" || name === "")
            return "";
        return root.notesDir + "/" + String(name) + ".txt";
    }

    function resolveTrashPath(name) {
        if (root.trashDir === "" || name === "")
            return "";
        return root.trashDir + "/" + String(name) + ".txt";
    }

    function canonicalNoteName(rawName) {
        var name = String(rawName || "")
            .replace(/[\u0000-\u001f\u007f\/]/g, "_")
            .replace(/\s+/g, " ")
            .trim();
        if (name === "")
            name = "Note";
        return name.substring(0, 60).trim();
    }

    function uniqueNoteName(rawName) {
        var baseName = root.canonicalNoteName(rawName);
        var name = baseName;
        var counter = 1;
        while (root.noteList.indexOf(name) !== -1 || root.pendingDeleteNote === name) {
            var suffix = " (" + counter + ")";
            name = baseName.substring(0, 60 - suffix.length).trim() + suffix;
            counter++;
        }
        return name;
    }

    function read() {
        if (ConfigService.dataDir === ""
                || root.initialized
                || root.initializing
                || bootstrapProc.running)
            return;

        root.initializing = true;
        root.loaded = false;
        root.errorText = "";
        root.bootstrapDataDir = ConfigService.dataDir;
        bootstrapProc.command = [
            "sh", "-c",
            "set -eu; "
                + "notes_dir=$1; legacy_file=$2; scratchpad_file=$3; trash_dir=$4; "
                + "umask 077; "
                + "mkdir -p -- \"$notes_dir\" \"$trash_dir\"; "
                + "for discarded in \"$trash_dir\"/*.txt \"$trash_dir\"/.*.txt; do "
                + "  if [ -f \"$discarded\" ]; then rm -f -- \"$discarded\"; fi; "
                + "done; "
                + "if [ -f \"$legacy_file\" ] && [ ! -e \"$scratchpad_file\" ]; then "
                + "  mv -- \"$legacy_file\" \"$scratchpad_file\"; "
                + "fi; "
                + "has_notes=false; "
                + "for candidate in \"$notes_dir\"/*.txt \"$notes_dir\"/.*.txt; do "
                + "  if [ -f \"$candidate\" ]; then has_notes=true; break; fi; "
                + "done; "
                + "if [ \"$has_notes\" = false ]; then : > \"$scratchpad_file\"; fi",
            "speshell-notes-bootstrap",
            root.notesDir,
            ConfigService.dataDir + "/scratchpad.txt",
            root.resolveNotePath("Scratchpad"),
            root.trashDir
        ];
        bootstrapProc.running = true;
    }

    function resetForDataDir() {
        saveTimer.stop();
        catalogRefreshTimer.stop();
        deleteCommitTimer.stop();
        root.noteList = [];
        root.currentNote = "";
        root.text = "";
        root.savedText = "";
        root.writeText = "";
        root.writeNote = "";
        root.loadTarget = "";
        notesFile.path = "";
        root.initialized = false;
        root.initializing = false;
        root.bootstrapped = false;
        root.loaded = false;
        root.loading = false;
        root.dirty = false;
        root.saving = false;
        root.saveQueued = false;
        root.mutating = false;
        root.mutationKind = "";
        root.mutationTarget = "";
        root.mutationNextNote = "";
        root.mutationNextList = [];
        root.mutationOriginalIndex = -1;
        root.pendingDeleteNote = "";
        root.pendingDeleteIndex = -1;
        root.externalReload = false;
        root.errorText = "";
    }

    function catalogNames() {
        var list = [];
        for (var i = 0; i < catalogModel.count; i++) {
            var fileName = String(catalogModel.get(i, "fileName") || "");
            if (fileName.length <= 4 || fileName.substring(fileName.length - 4) !== ".txt")
                continue;
            var name = fileName.substring(0, fileName.length - 4);
            if (name !== "" && list.indexOf(name) === -1)
                list.push(name);
        }
        return list;
    }

    function refreshCatalog() {
        if (!root.bootstrapped || catalogModel.status !== FolderListModel.Ready)
            return;

        var list = root.catalogNames();
        if (list.length === 0)
            list = ["Scratchpad"];
        root.noteList = list;

        if (!root.initialized) {
            var preferred = String(activeNoteFile.text() || "").trim();
            if (list.indexOf(preferred) === -1)
                preferred = list[0];

            root.initialized = true;
            root.initializing = false;
            root.loadNote(preferred, false);
            if (String(activeNoteFile.text() || "").trim() !== preferred)
                root.persistActiveNote(preferred);
            return;
        }

        if (!root.mutating && list.indexOf(root.currentNote) === -1) {
            if (root.dirty || root.saving) {
                root.errorText = "The active note was removed outside Speshell; your unsaved text is still open.";
                return;
            }
            root.loadNote(list[0], true);
        }
    }

    function loadNote(name, persistSelection) {
        root.loaded = false;
        root.loading = true;
        root.dirty = false;
        root.externalReload = false;
        root.currentNote = name;
        root.loadTarget = name;
        root.errorText = "";
        if (persistSelection)
            root.persistActiveNote(name);
        var nextPath = root.resolveNotePath(name);
        if (notesFile.path === nextPath)
            notesFile.reload();
        else
            notesFile.path = nextPath;
    }

    function finishLoad(initialText) {
        if (!root.loading || root.loadTarget !== root.currentNote)
            return;
        root.text = String(initialText);
        root.savedText = root.text;
        root.loaded = true;
        root.loading = false;
        root.dirty = false;
    }

    function failLoad() {
        if (!root.loading || root.loadTarget !== root.currentNote)
            return;
        root.loading = false;
        root.loaded = false;
        root.errorText = "Could not read " + root.currentNote + ". Your other notes were not changed.";
        catalogRefreshTimer.restart();
    }

    // Another program changed the open note. Speshell's own saves are ignored
    // because the reloaded text matches savedText.
    function handleExternalChange() {
        if (!root.loaded || root.loading || root.saving)
            return;
        root.externalReload = true;
        notesFile.reload();
    }

    function applyExternalText(nextText) {
        var next = String(nextText);
        if (next === root.savedText)
            return;
        if (root.dirty) {
            root.errorText = root.currentNote + " changed outside Speshell. Your unsaved text is still open and will replace that change when saved.";
            return;
        }
        saveTimer.stop();
        root.text = next;
        root.savedText = next;
        root.errorText = "";
    }

    function persistActiveNote(name) {
        if (root.activeNotePath === "")
            return;
        activeNoteFile.blockWrites = true;
        activeNoteFile.setText(name);
        activeNoteFile.blockWrites = false;
    }

    function selectNote(targetName) {
        if (!root.managementEnabled
                || targetName === ""
                || targetName === root.currentNote
                || root.noteList.indexOf(targetName) === -1)
            return false;
        if (!root.flush(true))
            return false;
        root.loadNote(targetName, true);
        return true;
    }

    function createNote(rawName) {
        if (!root.managementEnabled || mutationProc.running)
            return false;
        if (!root.flush(true))
            return false;

        var name = root.uniqueNoteName(rawName);
        root.mutating = true;
        root.mutationKind = "create";
        root.mutationTarget = name;
        root.mutationNextNote = name;
        root.mutationNextList = [];
        root.errorText = "";
        mutationProc.command = ["touch", "--", root.resolveNotePath(name)];
        mutationProc.running = true;
        return true;
    }

    function deleteNote(targetName) {
        var index = root.noteList.indexOf(targetName);
        if (!root.managementEnabled
                || mutationProc.running
                || root.pendingDeleteNote !== ""
                || root.noteList.length <= 1
                || index === -1)
            return false;
        if (targetName === root.currentNote && !root.flush(true))
            return false;

        var nextList = root.noteList.slice();
        nextList.splice(index, 1);
        var nextNote = root.currentNote;
        if (targetName === root.currentNote)
            nextNote = nextList[Math.min(index, nextList.length - 1)];

        root.mutating = true;
        root.mutationKind = "delete";
        root.mutationTarget = targetName;
        root.mutationNextNote = nextNote;
        root.mutationNextList = nextList;
        root.mutationOriginalIndex = index;
        root.errorText = "";
        mutationProc.command = [
            "mv", "--",
            root.resolveNotePath(targetName),
            root.resolveTrashPath(targetName)
        ];
        mutationProc.running = true;
        return true;
    }

    function undoDelete() {
        if (root.pendingDeleteNote === "" || root.mutating || mutationProc.running)
            return false;
        deleteCommitTimer.stop();
        root.mutating = true;
        root.mutationKind = "restore";
        root.mutationTarget = root.pendingDeleteNote;
        root.errorText = "";
        mutationProc.command = [
            "mv", "--",
            root.resolveTrashPath(root.pendingDeleteNote),
            root.resolveNotePath(root.pendingDeleteNote)
        ];
        mutationProc.running = true;
        return true;
    }

    function commitPendingDelete() {
        if (root.pendingDeleteNote === "" || root.mutating || mutationProc.running)
            return;
        root.mutating = true;
        root.mutationKind = "purge";
        root.mutationTarget = root.pendingDeleteNote;
        root.errorText = "";
        mutationProc.command = ["rm", "-f", "--", root.resolveTrashPath(root.pendingDeleteNote)];
        mutationProc.running = true;
    }

    function clearPendingDelete() {
        deleteCommitTimer.stop();
        root.pendingDeleteNote = "";
        root.pendingDeleteIndex = -1;
    }

    function finishMutation(succeeded, detail) {
        var kind = root.mutationKind;
        var target = root.mutationTarget;
        var nextNote = root.mutationNextNote;
        var nextList = root.mutationNextList;
        var originalIndex = root.mutationOriginalIndex;
        root.mutating = false;
        root.mutationKind = "";
        root.mutationTarget = "";
        root.mutationNextNote = "";
        root.mutationNextList = [];
        root.mutationOriginalIndex = -1;

        if (!succeeded) {
            if (kind === "purge")
                root.errorText = "Could not finish deleting " + target + ". You can still undo the deletion.";
            else
                root.errorText = "Could not " + kind + " " + target + "."
                    + (detail !== "" ? " " + detail : "");
            catalogRefreshTimer.restart();
            return;
        }

        if (kind === "create") {
            var createdList = root.noteList.slice();
            if (createdList.indexOf(target) === -1)
                createdList.push(target);
            root.noteList = createdList;
            root.loadNote(nextNote, true);
        } else if (kind === "delete") {
            root.noteList = nextList;
            root.pendingDeleteNote = target;
            root.pendingDeleteIndex = originalIndex;
            deleteCommitTimer.restart();
            if (target === root.currentNote)
                root.loadNote(nextNote, true);
        } else if (kind === "restore") {
            var restoredList = root.noteList.filter(function(name) { return name !== target; });
            var insertAt = Math.min(Math.max(0, root.pendingDeleteIndex), restoredList.length);
            restoredList.splice(insertAt, 0, target);
            root.noteList = restoredList;
            root.clearPendingDelete();
        } else if (kind === "purge") {
            root.clearPendingDelete();
        }
        catalogRefreshTimer.restart();
    }

    function setText(nextText) {
        if (!root.loaded || root.loading)
            return;
        var next = String(nextText);
        if (next === root.text)
            return;

        root.text = next;
        root.dirty = root.text !== root.savedText;
        if (root.dirty)
            saveTimer.restart();
        else
            saveTimer.stop();
    }

    function save() {
        if (!root.loaded || root.loading || root.notesPath === "")
            return;
        if (root.saving) {
            root.saveQueued = true;
            return;
        }
        if (root.text === root.savedText) {
            root.dirty = false;
            return;
        }

        root.writeText = root.text;
        root.writeNote = root.currentNote;
        root.saving = true;
        root.dirty = false;
        root.errorText = "";
        notesFile.setText(root.writeText);
    }

    function finishSave(succeeded) {
        var writtenText = root.writeText;
        var writtenNote = root.writeNote;
        var queued = root.saveQueued;
        root.writeText = "";
        root.writeNote = "";
        root.saveQueued = false;
        root.saving = false;

        if (succeeded && writtenNote === root.currentNote) {
            root.savedText = writtenText;
            root.errorText = "";
        } else if (!succeeded) {
            root.errorText = "Could not save " + writtenNote + ". Your text remains open.";
        }

        root.dirty = root.text !== root.savedText;
        if (root.dirty && queued && succeeded)
            root.save();
    }

    function flush(synchronous) {
        saveTimer.stop();
        if (!synchronous) {
            root.save();
            return true;
        }
        if (!root.loaded)
            return !root.dirty && !root.saving;

        notesFile.blockWrites = true;
        if (root.saving)
            notesFile.waitForJob();
        if (!root.saving && root.text !== root.savedText)
            root.save();
        if (root.saving)
            notesFile.waitForJob();
        notesFile.blockWrites = false;

        root.dirty = root.text !== root.savedText;
        return !root.saving && !root.dirty;
    }

    Connections {
        target: ConfigService
        function onDataDirChanged() {
            if (root.loaded)
                root.flush(true);
            root.resetForDataDir();
            root.read();
        }
    }

    Process {
        id: bootstrapProc
        running: false
        stderr: StdioCollector { id: bootstrapError }
        onExited: function(exitCode) {
            if (root.bootstrapDataDir !== ConfigService.dataDir) {
                root.resetForDataDir();
                root.read();
                return;
            }
            if (exitCode !== 0) {
                root.initializing = false;
                var detail = String(bootstrapError.text || "").trim();
                root.errorText = "Could not prepare the notes directory."
                    + (detail !== "" ? " " + detail : "");
                return;
            }
            root.bootstrapped = true;
            catalogRefreshTimer.restart();
        }
    }

    FolderListModel {
        id: catalogModel
        folder: root.bootstrapped && root.notesDir !== ""
            ? "file://" + root.notesDir
            : ""
        nameFilters: ["*.txt"]
        showFiles: true
        showDirs: false
        showHidden: true
        sortField: FolderListModel.Name
        sortCaseSensitive: false
        onCountChanged: catalogRefreshTimer.restart()
        onStatusChanged: catalogRefreshTimer.restart()
    }

    Timer {
        id: catalogRefreshTimer
        interval: 80
        repeat: false
        onTriggered: root.refreshCatalog()
    }

    FileView {
        id: activeNoteFile
        path: root.activeNotePath
        blockLoading: true
        atomicWrites: true
        printErrors: false
        onSaveFailed: root.errorText = "Could not remember the active note. Note content is unaffected."
    }

    Process {
        id: mutationProc
        running: false
        stderr: StdioCollector { id: mutationError }
        onExited: function(exitCode) {
            root.finishMutation(exitCode === 0, String(mutationError.text || "").trim());
        }
    }

    FileView {
        id: notesFile
        path: ""
        atomicWrites: true
        blockWrites: false
        printErrors: false
        watchChanges: true

        onFileChanged: root.handleExternalChange()
        onLoaded: {
            if (root.externalReload) {
                root.externalReload = false;
                root.applyExternalText(notesFile.text());
            } else {
                root.finishLoad(notesFile.text());
            }
        }
        onLoadFailed: {
            if (root.externalReload)
                root.externalReload = false;
            else
                root.failLoad();
        }
        onSaved: root.finishSave(true)
        onSaveFailed: root.finishSave(false)
    }

    Timer {
        id: saveTimer
        interval: 700
        repeat: false
        onTriggered: root.save()
    }

    Timer {
        id: deleteCommitTimer
        interval: 5000
        repeat: false
        onTriggered: root.commitPendingDelete()
    }
}
