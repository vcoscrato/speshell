pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// systemd-logind, for a laptop: whether the lid is closed, and the moment before the
// system sleeps, which a delay inhibitor holds back until Speshell has locked.
Singleton {
    id: root

    readonly property bool watching: FeatureSupport.supportsBattery
    property bool lidClosed: false
    // Whether the delay is held, so going to sleep waits for releaseSleep().
    readonly property bool holdingSleep: inhibitor.running

    // The system is about to sleep; it waits until releaseSleep() or a few seconds pass.
    signal aboutToSleep()
    signal resumed()

    function releaseSleep() {
        inhibitor.running = false;
    }

    // `gdbus monitor` lines: a property change and the sleep signal.
    function readEvent(line) {
        const lid = String(line).match(/'LidClosed': <(true|false)>/);
        if (lid)
            root.lidClosed = lid[1] === "true";
        const sleep = String(line).match(/\.PrepareForSleep \((true|false),\)/);
        if (!sleep)
            return;
        if (sleep[1] === "true") {
            root.aboutToSleep();
        } else {
            inhibitor.running = root.watching;
            root.resumed();
        }
    }

    Process {
        running: root.watching
        command: ["gdbus", "call", "--system", "--dest", "org.freedesktop.login1",
            "--object-path", "/org/freedesktop/login1", "--method", "org.freedesktop.DBus.Properties.Get",
            "org.freedesktop.login1.Manager", "LidClosed"]
        stdout: StdioCollector {
            onStreamFinished: root.lidClosed = text.indexOf("true") >= 0
        }
    }

    Process {
        running: root.watching
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1",
            "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser {
            onRead: line => root.readEvent(line)
        }
    }

    // Held while awake; logind waits for its release, up to InhibitDelayMaxSec (5 s).
    Process {
        id: inhibitor
        running: root.watching
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=Speshell",
            "--why=Locking the screen first", "sleep", "infinity"]
    }
}
