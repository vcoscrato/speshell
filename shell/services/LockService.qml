pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// The session lock: whether it's locked, and the password that unlocks it, checked
// by PAM as a login would. core/LockScreen.qml shows it. Whatever puts the system to
// sleep, as closing the lid, locks first: SessionService holds logind's sleep back
// until the lock covers every screen. logind's own lock and unlock
// (`loginctl lock-session`) work too.
//
// A marker in the runtime directory outlives a crash or a restart, and is read before
// anything shows, so a Speshell started again is locked from its first frame (with
// Hyprland's misc:allow_session_lock_restore, which lets a new locker take over).
// Without a runtime directory there is no marker: never one in a shared folder.
Singleton {
    id: root

    property bool locked: false
    // The compositor confirmed every screen is covered; set by LockScreen.
    property bool secure: false
    // Where PAM's conversation is: "idle", waiting for the password; "checking", PAM is
    // at work; "prompt", PAM asked something more, as a code or a new password, and
    // waits for what's typed; "unlocking", the way is open and the lock screen plays its
    // exit, which ends in unlock().
    property string phase: "idle"
    // PAM's question while the phase is "prompt", and whether its answer may show.
    property string prompt: ""
    property bool promptVisible: false
    // What PAM last said: a wrong password, a faillock wait, a notice.
    property string message: ""
    property bool messageIsError: false
    // Counts wrong passwords, so the prompt can shake at each.
    property int failures: 0
    // The password typed, shared by every screen's prompt.
    property string draft: ""
    readonly property string user: Quickshell.env("USER") || ""
    // The account's full name from its GECOS field, or the user name.
    property string userName: root.user
    // logind is waiting on the lock to sleep.
    property bool sleepHeld: false

    readonly property string markerPath: {
        const runtime = Quickshell.env("XDG_RUNTIME_DIR") || "";
        return runtime !== "" ? runtime + "/speshell-locked" : "";
    }

    // The password typed before PAM started, for its first question.
    property string answer: ""

    function lock() {
        // Locking again while the lock screen leaves keeps it.
        if (root.phase === "unlocking") {
            unlockSafety.stop();
            root.phase = "idle";
        }
        if (root.locked)
            return;
        root.message = "";
        root.messageIsError = false;
        root.draft = "";
        root.locked = true;
        if (root.markerPath !== "")
            Quickshell.execDetached(["touch", root.markerPath]);
        SessionService.setLockedHint(true);
    }

    // Sends what's typed: the password, which starts PAM, or the answer PAM waits for.
    function submit() {
        if (!root.locked || root.phase === "checking" || root.phase === "unlocking" || root.draft === "")
            return;
        root.message = "";
        root.messageIsError = false;
        if (root.phase === "prompt") {
            pam.respond(root.draft);
        } else {
            root.answer = root.draft;
            if (!pam.start()) {
                root.answer = "";
                root.message = "Could not start checking the password.";
                root.messageIsError = true;
                return;
            }
        }
        root.draft = "";
        root.phase = "checking";
    }

    // After a password, or from logind (`loginctl unlock-session`), which already
    // checked who asked: the lock screen leaves, then calls unlock().
    function release() {
        if (!root.locked || root.phase === "unlocking")
            return;
        if (pam.active)
            pam.abort();
        root.answer = "";
        root.draft = "";
        root.message = "";
        root.phase = "unlocking";
        unlockSafety.restart();
    }

    function unlock() {
        unlockSafety.stop();
        if (pam.active)
            pam.abort();
        root.phase = "idle";
        root.answer = "";
        root.draft = "";
        root.message = "";
        root.locked = false;
        if (root.markerPath !== "")
            Quickshell.execDetached(["rm", "-f", root.markerPath]);
        SessionService.setLockedHint(false);
    }

    // The compositor refused the lock, or ended it: nothing covers the screens, so the
    // session isn't locked, and the next lock() tries again.
    function lockFailed() {
        if (!root.locked)
            return;
        root.unlock();
        if (root.sleepHeld)
            SessionService.releaseSleep();
        NotificationService.addInternalNotification("lock", "Could not lock the screen",
            "The compositor refused the session lock.", true, 2);
    }

    function finishConversation() {
        root.phase = "idle";
        root.answer = "";
        root.draft = "";
    }

    PamContext {
        id: pam

        config: "login"

        onPamMessage: {
            if (!pam.responseRequired) {
                // Each line PAM says this time stays, as faillock's lockout and its wait.
                if (pam.message !== "") {
                    root.message = root.message !== "" ? root.message + "\n" + pam.message : pam.message;
                    root.messageIsError = root.messageIsError || pam.messageIsError;
                }
                return;
            }
            // The password answers the first question; any other waits for the user.
            if (root.answer !== "") {
                pam.respond(root.answer);
                root.answer = "";
                return;
            }
            root.prompt = pam.message.replace(/:\s*$/, "");
            root.promptVisible = pam.responseVisible;
            root.phase = "prompt";
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.release();
                return;
            }
            root.finishConversation();
            root.failures++;
            // What PAM said, as faillock's lockout, outranks a plain "wrong password".
            if (root.message === "")
                root.message = result === PamResult.MaxTries ? "Too many tries. Wait a moment."
                    : result === PamResult.Failed ? "Wrong password"
                    : "Could not check the password.";
            root.messageIsError = true;
        }

        onError: error => {
            root.finishConversation();
            root.message = "Could not check the password: " + PamError.toString(error);
            root.messageIsError = true;
        }
    }

    // Locks, then lets the system sleep once the lock covers every screen and has drawn
    // a frame there, so waking shows the lock at once. logind waits 5 s at most.
    Connections {
        target: SessionService

        function onAboutToSleep() {
            root.lock();
            root.sleepHeld = true;
            if (root.secure)
                sleepRelease.restart();
        }
        function onResumed() { root.sleepHeld = false; }
        function onLockRequested() { root.lock(); }
        function onUnlockRequested() { root.release(); }
    }

    onSecureChanged: {
        if (root.secure && root.sleepHeld)
            sleepRelease.restart();
    }

    // Bounds the lock screen's exit, should no screen report its end.
    Timer {
        id: unlockSafety
        interval: 3000
        onTriggered: root.unlock()
    }

    Timer {
        id: sleepRelease
        interval: 200
        onTriggered: SessionService.releaseSleep()
    }

    // A marker left by a Speshell that stopped locked, read at once rather than in the
    // background, so `locked` is never false while it's there.
    FileView {
        id: marker
        path: root.markerPath
        blockLoading: true
        printErrors: false
    }

    Process {
        running: root.user !== ""
        command: ["getent", "passwd", root.user]
        stdout: StdioCollector {
            onStreamFinished: {
                const name = (text.split(":")[4] || "").split(",")[0].trim();
                if (name !== "")
                    root.userName = name;
            }
        }
    }

    Component.onCompleted: {
        if (root.markerPath === "")
            return;
        marker.text();
        if (marker.loaded)
            root.lock();
    }
}
