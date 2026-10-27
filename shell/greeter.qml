pragma ComponentBehavior: Bound
// Quickshell's type info marks PanelWindow uncreatable, though QML creates it.
// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import Quickshell.Wayland
import qs.components
import qs.core
import qs.services

// Speshell's login screen, greetd's greeter: greeter/hyprland.lua runs it. It wears the
// theme the user last had, which speshell-greeter-theme copies out of their home, and
// starts the session picked, remembering the user and session for next time.
ShellRoot {
    id: root

    readonly property string stateDir: "/var/lib/speshell"
    // { name, label } for each person's account.
    property var users: []
    // { id, name, command, desktop } for each Wayland session.
    property var sessions: []
    property string user: ""
    property string session: ""
    // What was picked last time, until the accounts and sessions are known.
    property var remembered: ({})
    // The user's theme: { theme, colors, wallpaper }.
    property var theme: null
    property string draft: ""
    property string message: ""
    property bool messageIsError: false
    property int failures: 0
    readonly property bool busy: Greetd.state !== GreetdState.Inactive

    readonly property var current: root.sessions.find(entry => entry.id === root.session) || null

    function pickDefaults() {
        if (root.users.length > 0 && !root.users.some(entry => entry.name === root.user))
            root.user = (root.users.find(entry => entry.name === root.remembered.user) || root.users[0]).name;
        if (root.sessions.length > 0 && !root.current)
            root.session = (root.sessions.find(entry => entry.id === root.remembered.session)
                || root.sessions.find(entry => entry.id === "hyprland") || root.sessions[0]).id;
    }

    function submit() {
        if (root.busy || root.user === "" || !root.current)
            return;
        root.message = "";
        root.messageIsError = false;
        Greetd.createSession(root.user);
    }

    function fail(text) {
        root.draft = "";
        root.failures++;
        root.message = text;
        root.messageIsError = true;
        if (root.busy)
            Greetd.cancelSession();
    }

    // People's accounts: a regular uid and a shell to log in with.
    function readUsers(text) {
        root.users = String(text).split("\n").map(line => line.split(":")).filter(fields => {
            const uid = Number(fields[2]);
            return fields.length >= 7 && uid >= 1000 && uid < 60000 && !/(nologin|false)$/.test(fields[6]);
        }).map(fields => ({ name: fields[0], label: fields[4].split(",")[0].trim() || fields[0] }));
        root.pickDefaults();
    }

    // `file\tpath` lines, each followed by its entry's keys.
    function readSessions(text) {
        const found = [];
        let entry = null;
        for (const line of String(text).split("\n")) {
            const file = line.match(/^file\t.*\/([^/]+)\.desktop$/);
            if (file) {
                entry = { id: file[1], name: file[1], command: [], desktop: "", hidden: false };
                found.push(entry);
                continue;
            }
            const pair = line.match(/^([A-Za-z]+)=(.*)$/);
            if (!entry || !pair)
                continue;
            if (pair[1] === "Name")
                entry.name = pair[2];
            else if (pair[1] === "Exec")
                entry.command = pair[2].split(/\s+/).filter(word => word !== "" && !/^%[A-Za-z]$/.test(word));
            else if (pair[1] === "DesktopNames")
                entry.desktop = pair[2].replace(/;$/, "").replace(/;/g, ":");
            else if ((pair[1] === "NoDisplay" || pair[1] === "Hidden") && pair[2] === "true")
                entry.hidden = true;
        }
        root.sessions = found.filter(entry => !entry.hidden && entry.command.length > 0);
        root.pickDefaults();
    }

    function launch() {
        const entry = root.current;
        stateFile.setText(JSON.stringify({ user: root.user, session: root.session }));
        Greetd.launch(entry.command, [
            "XDG_SESSION_TYPE=wayland",
            "XDG_SESSION_DESKTOP=" + entry.id,
            "XDG_CURRENT_DESKTOP=" + (entry.desktop || entry.name)
        ], true);
    }

    Binding {
        target: Theme
        property: "paletteOverride"
        value: root.theme ? root.theme.colors : ThemeService.colors
    }

    // The theme's effects, from the shipped themes; ThemeService scans them itself.
    Binding {
        target: ThemeService
        property: "themeId"
        value: root.theme && root.theme.theme ? root.theme.theme : "cosmos"
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                Greetd.respond(root.draft);
                root.draft = "";
            } else if (message !== "") {
                root.message = message;
                root.messageIsError = error;
            }
        }

        function onAuthFailure(message) {
            root.fail(message !== "" ? message : "Wrong password");
        }

        function onReadyToLaunch() { root.launch(); }

        function onError(error) {
            root.fail("Could not log in: " + error);
        }
    }

    FileView {
        path: "/etc/passwd"
        onLoaded: root.readUsers(text())
    }

    FileView {
        id: stateFile

        path: root.stateDir + "/greeter/state.json"
        printErrors: false
        // Written before the greeter quits to start the session.
        blockWrites: true
        atomicWrites: true
        onLoaded: {
            try {
                root.remembered = JSON.parse(text()) || {};
            } catch (error) {
                root.remembered = {};
            }
            root.pickDefaults();
        }
    }

    FileView {
        path: root.user !== "" ? root.stateDir + "/theme/" + root.user + "/theme.json" : ""
        printErrors: false
        onLoaded: {
            try {
                root.theme = JSON.parse(text());
            } catch (error) {
                root.theme = null;
            }
        }
        onLoadFailed: root.theme = null
    }

    Process {
        running: true
        command: ["sh", "-c", "for f in /usr/share/wayland-sessions/*.desktop; do [ -f \"$f\" ] || continue; "
            + "printf 'file\\t%s\\n' \"$f\"; grep -E '^(Name|Exec|DesktopNames|NoDisplay|Hidden)=' \"$f\"; done"]
        stdout: StdioCollector {
            onStreamFinished: root.readSessions(text)
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: window

            required property var modelData
            // The credentials show on one screen, which has the keyboard.
            readonly property bool primary: window.modelData === HyprlandService.focusedScreen()

            screen: window.modelData
            color: Theme.crust
            focusable: window.primary
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "speshell-greeter"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: window.primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }

            Gate {
                anchors.fill: parent
                wallpaper: root.theme ? root.theme.wallpaper || "" : ""
                failures: root.failures
                footnote: HyprlandService.keyboardLayouts > 1 ? HyprlandService.keyboardLayout : ""

                Item {
                    visible: window.primary
                    width: parent.width
                    height: Math.max(people.height, name.implicitHeight)

                    SelectMenu {
                        id: people
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.users.length > 1
                        maxWidth: parent.width
                        options: root.users.map(entry => ({ value: entry.name, label: entry.label }))
                        currentValue: root.user
                        onValueSelected: value => {
                            root.user = value;
                            root.draft = "";
                            root.message = "";
                        }
                    }

                    Label {
                        id: name
                        visible: !people.visible
                        role: "title"
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: (root.users.find(entry => entry.name === root.user) || { label: "" }).label
                    }
                }

                Field {
                    id: password
                    visible: window.primary
                    masked: true
                    autoFocus: true
                    iconName: "lock"
                    placeholder: root.busy ? "Logging in…" : "Password"
                    onEdited: root.draft = password.text
                    onAccepted: root.submit()
                    onCancelled: root.draft = ""

                    Connections {
                        target: root

                        function onDraftChanged() {
                            if (password.text !== root.draft)
                                password.text = root.draft;
                        }
                    }
                }

                Label {
                    role: "caption"
                    visible: window.primary && root.message !== ""
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: root.message
                    color: root.messageIsError ? Theme.error : Theme.subtext
                }

                Item {
                    visible: window.primary
                    width: parent.width
                    height: Theme.controlHeight

                    SelectMenu {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.sessions.length > 1
                        options: root.sessions.map(entry => ({ value: entry.id, label: entry.name }))
                        currentValue: root.session
                        onValueSelected: value => root.session = value
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        IconButton {
                            iconName: "sleep"
                            tooltipText: "Sleep"
                            onClicked: Quickshell.execDetached(["systemctl", "suspend"])
                        }

                        IconButton {
                            iconName: "restart"
                            tooltipText: "Restart"
                            onClicked: Quickshell.execDetached(["systemctl", "reboot"])
                        }

                        IconButton {
                            iconName: "power"
                            tooltipText: "Power off"
                            onClicked: Quickshell.execDetached(["systemctl", "poweroff"])
                        }
                    }
                }
            }
        }
    }
}
