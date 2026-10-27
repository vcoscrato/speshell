pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.services

// The session lock: every screen covered by the gate, each with a password field
// (what is typed shows in all), until PAM takes the password. Outside Runtime, so the
// session still locks while config.ini is invalid. `speshell lock` locks.
Scope {
    id: root

    readonly property string user: Quickshell.env("USER") || ""
    // The account's full name from its GECOS field, or the user name.
    property string userName: root.user

    WlSessionLock {
        id: sessionLock

        locked: LockService.locked

        WlSessionLockSurface {
            color: Theme.crust

            Gate {
                anchors.fill: parent
                wallpaper: ThemeService.shownWallpaper
                failures: LockService.failures
                footnote: HyprlandService.keyboardLayouts > 1 ? HyprlandService.keyboardLayout : ""

                Label {
                    role: "title"
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.userName
                }

                Field {
                    id: password
                    masked: true
                    autoFocus: true
                    iconName: "lock"
                    placeholder: LockService.checking ? "Checking…" : "Password"
                    onEdited: LockService.draft = password.text
                    onAccepted: LockService.submit()
                    onCancelled: LockService.draft = ""

                    Connections {
                        target: LockService

                        function onDraftChanged() {
                            if (password.text !== LockService.draft)
                                password.text = LockService.draft;
                        }
                    }
                }

                Label {
                    role: "caption"
                    visible: LockService.message !== ""
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: LockService.message
                    color: LockService.messageIsError ? Theme.error : Theme.subtext
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
            PanelService.dismiss();
            LauncherService.close();
            ThemeService.closeGallery();
        }
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

    IpcHandler {
        target: "lock"

        function lock(): void { LockService.lock(); }
        function get(): string { return LockService.locked ? "locked" : "unlocked"; }
    }
}
