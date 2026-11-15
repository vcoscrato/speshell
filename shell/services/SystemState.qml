pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "Shell.js" as Shell

// Speshell itself: its version and Quickshell's, and relaunching.
Singleton {
    id: root

    // Speshell's version: the checkout's revision, or the package's.
    property string appVersion: "Unknown"
    // Where Speshell is: the folder of shell.qml.
    readonly property string appDir: Shell.localPath(Qt.resolvedUrl("..")).replace(/\/$/, "")
    property bool relaunching: false
    readonly property bool canRelaunch: !root.relaunching && !ConfigService.writing

    // Starts a new Speshell once this process has exited; notes are saved first.
    function relaunch() {
        if (!root.canRelaunch)
            return;
        root.relaunching = true;
        NotesService.flush(true);
        const shellPath = Quickshell.shellDir || Quickshell.shellRoot;
        Quickshell.execDetached(Shell.script("system.sh", ["relaunch", String(Quickshell.processId)]
            .concat(shellPath !== "" ? ["-p", shellPath] : [])));
        Qt.quit();
    }

    Process {
        running: true
        command: Shell.script("system.sh", ["version", root.appDir])
        stdout: StdioCollector {
            onStreamFinished: root.appVersion = text.trim() || "Unknown"
        }
    }
}
