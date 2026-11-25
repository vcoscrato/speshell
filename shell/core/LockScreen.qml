pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

// The session lock: every screen covered by the gate, each with a password field
// (what is typed shows in all), until PAM takes the password. Outside Runtime, so the
// session still locks while config.ini is invalid.
Scope {
    id: root

    // A lock the compositor refused or ended reads unlocked, with no signal but secure's.
    function checkLock() {
        if (LockService.locked && !sessionLock.locked)
            LockService.lockFailed();
    }

    WlSessionLock {
        id: sessionLock

        onSecureChanged: root.checkLock()

        locked: LockService.locked

        WlSessionLockSurface {
            color: Theme.crust

            Gate {
                anchors.fill: parent
                wallpaper: ThemeService.shownWallpaper
                failures: LockService.failures
                footnote: HyprlandService.keyboardLayouts > 1 ? HyprlandService.keyboardLayout : ""
                leaving: LockService.phase === "unlocking"
                onDeparted: LockService.unlock()

                Label {
                    role: "title"
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: LockService.userName
                }

                GatePassword {
                    draft: LockService.draft
                    phase: LockService.phase
                    prompt: LockService.prompt
                    promptVisible: LockService.promptVisible
                    message: LockService.message
                    messageIsError: LockService.messageIsError
                    onDraftEdited: text => LockService.draft = text
                    onAccepted: LockService.submit()
                }
            }
        }
    }

    Binding {
        target: LockService
        property: "secure"
        value: sessionLock.secure
    }

    // The desktop comes back as it was, minus what was open over it.
    Connections {
        target: LockService

        function onLockedChanged() {
            if (!LockService.locked)
                return;
            Qt.callLater(root.checkLock);
            PanelService.dismiss();
            LauncherService.close();
            ThemeService.closeGallery();
        }
    }
}
