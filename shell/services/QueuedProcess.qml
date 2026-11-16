import QtQuick
import Quickshell.Io

// A Process for something read or written again and again. request() runs it, or,
// while it runs, runs it once more after, since that run may have started before
// the change the caller is reporting; a command bound to the latest value then
// writes or reads that. `input`, when set before it starts, goes to its stdin,
// which then closes.
Process {
    id: root

    // Text for stdin, written once it starts; it empties then.
    property string input: ""
    // Whether another run follows this one; it holds until that run starts.
    property bool queued: false

    function request() {
        if (root.running)
            root.queued = true;
        else
            root.running = true;
    }

    function rerun() {
        root.queued = false;
        root.running = true;
    }

    stdinEnabled: true
    onStarted: {
        if (root.input !== "")
            root.write(root.input);
        root.input = "";
        // Closes stdin, the end of the input.
        root.stdinEnabled = false;
    }
    // After `exited`, so its handlers still see `queued`.
    onRunningChanged: {
        if (root.running)
            return;
        root.stdinEnabled = true;
        if (root.queued)
            Qt.callLater(root.rerun);
    }
}
