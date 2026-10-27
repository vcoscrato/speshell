pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// The session lock: whether it's locked, and the password that unlocks it, checked
// by PAM as a login would. core/LockScreen.qml shows it. A marker in the runtime
// directory outlives a crash, so a Speshell started again locks again at once (with
// Hyprland's misc:allow_session_lock_restore, which lets a new locker take over).
Singleton {
    id: root

    property bool locked: false
    // The compositor confirmed every screen is covered; set by LockScreen.
    property bool secure: false
    readonly property bool checking: pam.active
    // What PAM last said: a wrong password, a faillock wait, a prompt.
    property string message: ""
    property bool messageIsError: false
    // Counts wrong passwords, so the prompt can shake at each.
    property int failures: 0
    // The password typed, shared by every screen's prompt.
    property string draft: ""

    readonly property string markerPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/speshell-locked"
    readonly property string sessionId: Quickshell.env("XDG_SESSION_ID") || ""

    signal unlocked()

    function lock() {
        if (root.locked)
            return;
        root.message = "";
        root.messageIsError = false;
        root.draft = "";
        root.locked = true;
        Quickshell.execDetached(["touch", root.markerPath]);
        root.hintLocked(true);
    }

    function submit() {
        if (!root.locked || pam.active || root.draft === "")
            return;
        root.message = "";
        root.messageIsError = false;
        if (!pam.start()) {
            root.message = "Could not start checking the password.";
            root.messageIsError = true;
        }
    }

    // After a password, or from logind (`loginctl unlock-session`), which already
    // checked who asked.
    function unlock() {
        if (pam.active)
            pam.abort();
        root.draft = "";
        root.message = "";
        root.locked = false;
        Quickshell.execDetached(["rm", "-f", root.markerPath]);
        root.hintLocked(false);
        root.unlocked();
    }

    // Tells logind, which shows it as the session's LockedHint.
    function hintLocked(on) {
        if (root.sessionId === "")
            return;
        Quickshell.execDetached(["gdbus", "call", "--system", "--dest", "org.freedesktop.login1",
            "--object-path", "/org/freedesktop/login1/session/auto",
            "--method", "org.freedesktop.login1.Session.SetLockedHint", on ? "true" : "false"]);
    }

    PamContext {
        id: pam

        config: "login"

        onPamMessage: {
            if (pam.responseRequired) {
                pam.respond(root.draft);
                root.draft = "";
            } else if (pam.message !== "") {
                root.message = pam.message;
                root.messageIsError = pam.messageIsError;
            }
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlock();
                return;
            }
            root.draft = "";
            root.failures++;
            // faillock's own wait outranks a plain "wrong password".
            if (!root.messageIsError || root.message === "") {
                root.message = result === PamResult.MaxTries ? "Too many tries. Wait a moment."
                    : result === PamResult.Failed ? "Wrong password"
                    : "Could not check the password.";
                root.messageIsError = true;
            }
        }

        onError: error => {
            root.draft = "";
            root.message = "Could not check the password: " + PamError.toString(error);
            root.messageIsError = true;
        }
    }

    // A marker left by a Speshell that died locked.
    FileView {
        path: root.markerPath
        printErrors: false
        onLoaded: root.lock()
    }
}
