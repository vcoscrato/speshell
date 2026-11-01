pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// systemd-logind: the moment before the system sleeps, which a delay inhibitor holds
// back until Speshell has locked; `loginctl lock-session` and `unlock-session`; the
// session's LockedHint; whether the system can hibernate; and on a laptop, whether the
// lid is closed.
Singleton {
    id: root

    readonly property bool laptop: FeatureSupport.supportsBattery
    property bool lidClosed: false
    // A swap that fits memory, and resume set up.
    property bool canHibernate: false
    // This session's object, as logind escapes its id: "2" is _32.
    readonly property string sessionPath: {
        const id = Quickshell.env("XDG_SESSION_ID") || "";
        if (id === "")
            return "";
        return "/org/freedesktop/login1/session/" + id.replace(/[^A-Za-z0-9]|^[0-9]/g,
            c => "_" + c.charCodeAt(0).toString(16).padStart(2, "0"));
    }

    // The system is about to sleep; it waits until releaseSleep() or a few seconds pass.
    signal aboutToSleep()
    signal resumed()
    signal lockRequested()
    signal unlockRequested()

    function releaseSleep() {
        inhibitor.running = false;
    }

    // `gdbus call` of logind's `method` on the object at `path`.
    function logindCall(path, method, args) {
        return ["gdbus", "call", "--system", "--dest", "org.freedesktop.login1",
            "--object-path", path, "--method", method].concat(args || []);
    }

    // Tells logind whether the session is locked, as its LockedHint.
    function setLockedHint(on) {
        if (root.sessionPath !== "")
            Quickshell.execDetached(root.logindCall("/org/freedesktop/login1/session/auto",
                "org.freedesktop.login1.Session.SetLockedHint", [on ? "true" : "false"]));
    }

    // `gdbus monitor` lines: a property change, the sleep signal, and this session's
    // lock and unlock.
    function readEvent(line) {
        const text = String(line);
        const lid = text.match(/'LidClosed': <(true|false)>/);
        if (lid)
            root.lidClosed = lid[1] === "true";
        if (root.sessionPath !== "" && text.startsWith(root.sessionPath + ": ")) {
            if (text.endsWith(".Session.Lock ()"))
                root.lockRequested();
            else if (text.endsWith(".Session.Unlock ()"))
                root.unlockRequested();
        }
        const sleep = text.match(/\.PrepareForSleep \((true|false),\)/);
        if (!sleep)
            return;
        if (sleep[1] === "true") {
            root.aboutToSleep();
        } else {
            inhibitor.running = true;
            root.resumed();
        }
    }

    Process {
        running: root.laptop
        command: root.logindCall("/org/freedesktop/login1", "org.freedesktop.DBus.Properties.Get",
            ["org.freedesktop.login1.Manager", "LidClosed"])
        stdout: StdioCollector {
            onStreamFinished: root.lidClosed = text.indexOf("true") >= 0
        }
    }

    // Prints ('yes',) when hibernating works.
    Process {
        running: true
        command: root.logindCall("/org/freedesktop/login1", "org.freedesktop.login1.Manager.CanHibernate")
        stdout: StdioCollector {
            onStreamFinished: root.canHibernate = text.indexOf("'yes'") >= 0
        }
    }

    Process {
        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]
        stdout: SplitParser {
            onRead: line => root.readEvent(line)
        }
    }

    // Held while awake; logind waits for its release, up to InhibitDelayMaxSec (5 s).
    Process {
        id: inhibitor
        running: true
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=Speshell",
            "--why=Locking the screen first", "sleep", "infinity"]
    }
}
