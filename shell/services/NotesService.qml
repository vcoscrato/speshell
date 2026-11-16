pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "Shell.js" as Shell

// Notes as text files under <dataDir>/notes: the list, the open note, saving as you
// type, edits made outside Speshell, and creating and deleting notes with an undo.
Singleton {
    id: root

    // "" until read() first runs, "preparing" the folder, "listing" its notes the first
    // time, "loading" the open note, "ready" with it open, or "unreadable" when it
    // could not be read.
    property string phase: ""
    // The file operation running, or null: { kind: "create", "delete", "restore", or
    // "purge"; note; next, the note that opens after a create or delete; index, where a
    // deleted note was in the list; and purge, the note a delete's Undo replaces, which
    // goes for good once it's done }.
    property var operation: null
    // The write in flight, or null: { note, text }.
    property var writing: null
    property var noteList: []
    property string currentNote: ""
    property string text: ""
    // The open note's text as last read or written.
    property string savedText: ""
    property string errorText: ""
    // A deleted note waits in the trash this long, for Undo, before it goes.
    readonly property int undoMs: 5000
    property string pendingDeleteNote: ""
    property int pendingDeleteIndex: -1

    readonly property string notesDir: ConfigService.dataDir !== "" ? ConfigService.dataDir + "/notes" : ""
    readonly property string activeNotePath: root.notesDir !== "" ? root.notesDir + "/.active" : ""
    readonly property string trashDir: root.notesDir !== "" ? root.notesDir + "/.trash" : ""
    readonly property string notesPath: root.notePath(root.currentNote)
    readonly property bool loaded: root.phase === "ready"
    readonly property bool dirty: root.text !== root.savedText
    readonly property bool mutating: root.operation !== null
    // Notes can be switched, made, and deleted, also away from a note that can't be read.
    readonly property bool managementEnabled: (root.loaded || root.phase === "unreadable") && !root.mutating

    function notePath(name) {
        return root.notesDir !== "" && name !== "" ? root.notesDir + "/" + name + ".txt" : "";
    }

    function trashPath(name) {
        return root.trashDir !== "" && name !== "" ? root.trashDir + "/" + name + ".txt" : "";
    }

    function canonicalNoteName(rawName) {
        const name = String(rawName || "")
            .replace(/[\u0000-\u001f\u007f\/]/g, "_")
            .replace(/\s+/g, " ")
            .trim();
        return (name || "Note").substring(0, 60).trim();
    }

    function uniqueNoteName(rawName) {
        const baseName = root.canonicalNoteName(rawName);
        let name = baseName;
        for (let counter = 1; root.noteList.includes(name) || root.pendingDeleteNote === name; counter++) {
            const suffix = " (" + counter + ")";
            name = baseName.substring(0, 60 - suffix.length).trim() + suffix;
        }
        return name;
    }

    function read() {
        if (root.phase !== "" || root.notesDir === "" || prepareProc.running)
            return;
        root.phase = "preparing";
        root.errorText = "";
        prepareProc.command = Shell.script("notes.sh", [root.notesDir, root.notePath("Scratchpad"), root.trashDir]);
        prepareProc.running = true;
    }

    function finishPrepare(exitCode, errorText) {
        // The data folder changed meanwhile.
        if (root.phase !== "preparing") {
            root.read();
            return;
        }
        if (exitCode !== 0) {
            root.phase = "";
            const detail = errorText.trim();
            root.errorText = "Could not prepare the notes directory." + (detail !== "" ? " " + detail : "");
            return;
        }
        root.phase = "listing";
        catalogRefreshTimer.restart();
    }

    function reset() {
        saveTimer.stop();
        catalogRefreshTimer.stop();
        deleteCommitTimer.stop();
        root.phase = "";
        root.operation = null;
        root.writing = null;
        root.noteList = [];
        root.currentNote = "";
        root.text = "";
        root.savedText = "";
        root.pendingDeleteNote = "";
        root.pendingDeleteIndex = -1;
        root.errorText = "";
        notesFile.path = "";
    }

    function catalogNames() {
        const names = [];
        for (let i = 0; i < catalogModel.count; i++) {
            const fileName = String(catalogModel.get(i, "fileName") || "");
            const name = fileName.endsWith(".txt") ? fileName.slice(0, -4) : "";
            if (name !== "" && !names.includes(name))
                names.push(name);
        }
        return names;
    }

    function refreshCatalog() {
        if (root.phase === "" || root.phase === "preparing" || catalogModel.status !== FolderListModel.Ready)
            return;
        const list = root.catalogNames();
        root.noteList = list.length > 0 ? list : ["Scratchpad"];

        if (root.phase === "listing") {
            const remembered = activeNoteFile.text().trim();
            const preferred = root.noteList.includes(remembered) ? remembered : root.noteList[0];
            root.loadNote(preferred, preferred !== remembered);
            return;
        }
        if (root.mutating || root.noteList.includes(root.currentNote))
            return;
        if (root.dirty || root.writing) {
            root.errorText = "The active note was removed outside Speshell; your unsaved text is still open.";
            return;
        }
        root.loadNote(root.noteList[0], true);
    }

    // Callers save the open note first; what is left unsaved is dropped.
    function loadNote(name, remember) {
        root.phase = "loading";
        root.currentNote = name;
        root.savedText = root.text;
        root.errorText = "";
        if (remember)
            root.rememberActiveNote(name);
        const path = root.notePath(name);
        if (notesFile.path === path)
            notesFile.reload();
        else
            notesFile.path = path;
    }

    function finishLoad(loadedText) {
        if (notesFile.path !== root.notesPath)
            return;
        if (root.phase === "loading") {
            root.text = loadedText;
            root.savedText = loadedText;
            root.phase = "ready";
        } else if (root.phase === "ready") {
            root.applyExternalText(loadedText);
        }
    }

    function failLoad() {
        if (root.phase !== "loading" || notesFile.path !== root.notesPath)
            return;
        root.phase = "unreadable";
        // Not the last note's text under this one's name.
        root.text = "";
        root.savedText = "";
        root.errorText = "Could not read " + root.currentNote + ". Your other notes were not changed.";
        catalogRefreshTimer.restart();
    }

    // Another program changed the open note; Speshell's own writes read back as they are.
    function handleExternalChange() {
        if (root.phase === "ready" && !root.writing)
            notesFile.reload();
    }

    function applyExternalText(next) {
        if (next === root.savedText)
            return;
        if (next === root.text) {
            root.savedText = next;
            return;
        }
        if (root.dirty) {
            root.errorText = root.currentNote + " changed outside Speshell. Your unsaved text is still open and will replace that change when saved.";
            return;
        }
        saveTimer.stop();
        root.text = next;
        root.savedText = next;
        root.errorText = "";
    }

    function rememberActiveNote(name) {
        if (root.activeNotePath === "")
            return;
        activeNoteFile.blockWrites = true;
        activeNoteFile.setText(name);
        activeNoteFile.blockWrites = false;
    }

    function selectNote(name) {
        // The open note again only to retry reading it.
        const again = name === root.currentNote && root.phase !== "unreadable";
        if (!root.managementEnabled || name === "" || again || !root.noteList.includes(name))
            return false;
        if (!root.flush(true))
            return false;
        root.loadNote(name, true);
        return true;
    }

    function createNote(rawName) {
        if (!root.managementEnabled || !root.flush(true))
            return false;
        const name = root.uniqueNoteName(rawName);
        root.run({ kind: "create", note: name, next: name }, ["touch", "--", root.notePath(name)]);
        return true;
    }

    function deleteNote(name) {
        const index = root.noteList.indexOf(name);
        if (!root.managementEnabled || root.noteList.length <= 1 || index === -1)
            return false;
        if (name === root.currentNote && !root.flush(true))
            return false;
        const rest = root.noteList.filter(note => note !== name);
        const next = name === root.currentNote ? rest[Math.min(index, rest.length - 1)] : root.currentNote;
        root.run({ kind: "delete", note: name, next: next, index: index, purge: root.pendingDeleteNote },
            ["mv", "--", root.notePath(name), root.trashPath(name)]);
        return true;
    }

    function undoDelete() {
        if (root.pendingDeleteNote === "" || root.mutating)
            return false;
        deleteCommitTimer.stop();
        const name = root.pendingDeleteNote;
        root.run({ kind: "restore", note: name }, ["mv", "--", root.trashPath(name), root.notePath(name)]);
        return true;
    }

    // Once Undo's time is up; an operation running then purges it when it finishes.
    function commitPendingDelete() {
        if (root.pendingDeleteNote !== "" && !root.mutating)
            root.purge(root.pendingDeleteNote);
    }

    function purge(name) {
        root.run({ kind: "purge", note: name }, ["rm", "-f", "--", root.trashPath(name)]);
    }

    function run(operation, command) {
        root.operation = operation;
        root.errorText = "";
        operationProc.command = command;
        operationProc.running = true;
    }

    function clearPendingDelete() {
        deleteCommitTimer.stop();
        root.pendingDeleteNote = "";
        root.pendingDeleteIndex = -1;
    }

    function finishOperation(succeeded, detail) {
        const operation = root.operation;
        // Gone when the data folder changed meanwhile.
        if (!operation)
            return;
        root.operation = null;
        catalogRefreshTimer.restart();
        if (!succeeded) {
            root.errorText = operation.kind !== "purge"
                ? "Could not " + operation.kind + " " + operation.note + "." + (detail !== "" ? " " + detail : "")
                : "Could not finish deleting " + operation.note + "."
                    + (operation.note === root.pendingDeleteNote ? " You can still undo the deletion." : "");
        } else if (operation.kind === "create") {
            if (!root.noteList.includes(operation.note))
                root.noteList = root.noteList.concat([operation.note]);
            root.loadNote(operation.next, true);
        } else if (operation.kind === "delete") {
            root.noteList = root.noteList.filter(note => note !== operation.note);
            root.pendingDeleteNote = operation.note;
            root.pendingDeleteIndex = operation.index;
            deleteCommitTimer.restart();
            if (operation.note === root.currentNote)
                root.loadNote(operation.next, true);
        } else if (operation.kind === "restore") {
            const restored = root.noteList.filter(note => note !== operation.note);
            restored.splice(Math.min(Math.max(0, root.pendingDeleteIndex), restored.length), 0, operation.note);
            root.noteList = restored;
            root.clearPendingDelete();
        } else if (operation.note === root.pendingDeleteNote) {
            root.clearPendingDelete();
        }
        // The note whose Undo a delete replaced, or one whose time ran out meanwhile.
        if (succeeded && operation.kind === "delete" && operation.purge !== "")
            root.purge(operation.purge);
        else if (root.pendingDeleteNote !== "" && operation.note !== root.pendingDeleteNote && !deleteCommitTimer.running)
            root.commitPendingDelete();
    }

    function setText(next) {
        if (root.phase !== "ready" || next === root.text)
            return;
        root.text = next;
        if (root.dirty)
            saveTimer.restart();
        else
            saveTimer.stop();
    }

    function save() {
        if (root.phase !== "ready" || root.writing || !root.dirty)
            return;
        root.writing = { note: root.currentNote, text: root.text };
        root.errorText = "";
        notesFile.setText(root.text);
    }

    function finishWrite(succeeded) {
        const written = root.writing;
        if (!written)
            return;
        root.writing = null;
        if (!succeeded) {
            root.errorText = "Could not save " + written.note + ". Your text remains open.";
            return;
        }
        if (written.note !== root.currentNote)
            return;
        root.savedText = written.text;
        root.errorText = "";
        // What was typed during the write.
        root.save();
    }

    // Saves the open note: at once, or with `synchronous`, before returning whether
    // everything is saved.
    function flush(synchronous) {
        saveTimer.stop();
        if (!synchronous) {
            root.save();
            return true;
        }
        if (root.phase === "ready") {
            notesFile.blockWrites = true;
            if (root.writing)
                notesFile.waitForJob();
            root.save();
            if (root.writing)
                notesFile.waitForJob();
            notesFile.blockWrites = false;
        }
        return !root.writing && !root.dirty;
    }

    Connections {
        target: ConfigService

        function onDataDirChanged() {
            root.flush(true);
            root.reset();
            root.read();
        }
    }

    Process {
        id: prepareProc
        stderr: StdioCollector { id: prepareErrors }
        onExited: exitCode => root.finishPrepare(exitCode, prepareErrors.text)
    }

    FolderListModel {
        id: catalogModel
        folder: root.phase !== "" && root.phase !== "preparing" && root.notesDir !== "" ? "file://" + root.notesDir : ""
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
        id: operationProc
        stderr: StdioCollector { id: operationErrors }
        onExited: exitCode => root.finishOperation(exitCode === 0, operationErrors.text.trim())
    }

    FileView {
        id: notesFile
        atomicWrites: true
        printErrors: false
        watchChanges: true
        onFileChanged: root.handleExternalChange()
        onLoaded: root.finishLoad(notesFile.text())
        onLoadFailed: root.failLoad()
        onSaved: root.finishWrite(true)
        onSaveFailed: root.finishWrite(false)
    }

    Timer {
        id: saveTimer
        interval: 700
        onTriggered: root.save()
    }

    Timer {
        id: deleteCommitTimer
        interval: root.undoMs
        onTriggered: root.commitPendingDelete()
    }
}
