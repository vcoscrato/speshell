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
    property string quickshellVersion: ""
    readonly property string appDir: Qt.resolvedUrl("..").toString().replace(/^file:\/\//, "")
    property bool relaunching: false
    readonly property bool canRelaunch: !root.relaunching && !ConfigService.savingConfig

    // Starts a new Speshell once this process has exited; notes are saved first.
    function relaunch() {
        if (!root.canRelaunch)
            return;

        root.relaunching = true;
        NotesService.flush(true);

        var shellPath = Quickshell.shellDir !== ""
            ? Quickshell.shellDir
            : Quickshell.shellRoot;
        var command = "launcher=$(readlink -f /proc/" + Quickshell.processId + "/exe 2>/dev/null || command -v quickshell || printf quickshell); "
            + "while kill -0 " + Quickshell.processId + " 2>/dev/null; do sleep 0.05; done; "
            + "sleep 0.1; "
            + "exec \"$launcher\" --daemonize";
        if (shellPath !== "")
            command += " -p " + Shell.quote(shellPath);

        Quickshell.execDetached(["sh", "-c", command]);
        Qt.quit();
    }

    Process {
        id: appVersionProc
        running: false

        stdout: StdioCollector { id: appVersionOutput }

        onRunningChanged: if (!running) {
            var version = (appVersionOutput.text || "").trim();
            root.appVersion = version !== "" ? version : "Unknown";
        }
    }

    Process {
        running: true
        command: ["quickshell", "--version"]
        stdout: SplitParser {
            onRead: line => {
                const match = String(line || "").match(/^Quickshell\s+(\S+)/i);
                if (match)
                    root.quickshellVersion = match[1];
            }
        }
    }

    Component.onCompleted: {
        appVersionProc.command = [
            "sh", "-c",
            "app_dir=$1; "
                + "if command -v git >/dev/null 2>&1 "
                + "&& git -C \"$app_dir\" rev-parse --is-inside-work-tree >/dev/null 2>&1; then "
                + "printf 'r%s.g%s\\n' "
                + "\"$(git -C \"$app_dir\" rev-list --count HEAD)\" "
                + "\"$(git -C \"$app_dir\" rev-parse --short=7 HEAD)\"; "
                + "elif package_info=$(pacman -Q speshell-git 2>/dev/null || pacman -Q speshell 2>/dev/null); then "
                + "set -- $package_info; version=$2; printf '%s\\n' \"${version%-*}\"; "
                + "else printf 'Unknown\\n'; fi",
            "speshell-version",
            root.appDir
        ];
        appVersionProc.running = true;
    }
}
