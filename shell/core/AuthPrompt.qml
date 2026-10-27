pragma ComponentBehavior: Bound
// Quickshell's type info marks PanelWindow uncreatable, though QML creates it.
// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs.components
import qs.services

// Speshell's polkit agent: when something asks for an administrator's password, as
// pkexec does, a prompt over the focused screen. Outside Runtime, so it works while
// config.ini is invalid.
Scope {
    id: root

    readonly property var flow: root.flowOf(agent)
    property var targetScreen: null
    property int failures: 0

    // Untyped, since qmllint can't resolve Quickshell's AuthFlow type.
    function flowOf(polkitAgent) {
        return polkitAgent.flow;
    }

    PolkitAgent {
        id: agent

        onIsActiveChanged: if (agent.isActive) root.targetScreen = HyprlandService.focusedScreen()
    }

    Connections {
        target: root.flow

        function onAuthenticationFailed() {
            password.text = "";
            root.failures++;
            if (Theme.motion)
                shake.restart();
        }
    }

    PanelWindow {
        id: window

        visible: agent.isActive && root.flow !== null && root.targetScreen !== null
        screen: root.targetScreen
        color: Theme.alpha(Theme.crust, 0.6)
        focusable: true
        aboveWindows: true
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.namespace: "speshell-auth"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: window.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }

        onVisibleChanged: {
            root.failures = 0;
            if (window.visible)
                password.focusInput();
        }

        HyprlandFocusGrab {
            active: window.visible && HyprlandService.running
            windows: [window]
        }

        Surface {
            anchors.centerIn: parent
            width: Theme.panelWidth + Theme.spacingXL * 2
            height: content.implicitHeight + Theme.spacingXL * 2
            backdrop: true
            roundTopLeft: true
            roundTopRight: true
            roundBottomRight: true
            roundBottomLeft: true
            transform: Translate { id: offset }

            Column {
                id: content
                x: Theme.spacingXL
                y: Theme.spacingXL
                width: parent.width - Theme.spacingXL * 2
                spacing: Theme.spacingMedium

                Row {
                    spacing: Theme.spacingSmall

                    AppIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "lock"
                        size: Theme.iconSizeMedium
                        iconColor: Theme.accent
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "heading"
                        text: "Authentication required"
                    }
                }

                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: root.flow ? root.flow.message : ""
                }

                Field {
                    id: password
                    masked: !(root.flow && root.flow.responseVisible)
                    iconName: "lock"
                    // PAM's prompt, as "Password:".
                    placeholder: root.flow ? root.flow.inputPrompt.replace(/:\s*$/, "") || "Password" : ""
                    onAccepted: submit.clicked()
                    onCancelled: cancel.clicked()
                }

                Label {
                    role: "caption"
                    width: parent.width
                    wrapMode: Text.Wrap
                    visible: text !== ""
                    readonly property bool error: root.flow && (root.flow.supplementaryIsError || root.flow.supplementaryMessage === "")
                    text: root.flow && root.flow.supplementaryMessage !== "" ? root.flow.supplementaryMessage
                        : root.failures > 0 ? "Wrong password, try again" : ""
                    color: error ? Theme.error : Theme.subtext
                }

                Row {
                    anchors.right: parent.right
                    spacing: Theme.spacingSmall

                    ActionButton {
                        id: cancel
                        text: "Cancel"
                        onClicked: if (root.flow) root.flow.cancelAuthenticationRequest()
                    }

                    ActionButton {
                        id: submit
                        text: "Authenticate"
                        kind: "primary"
                        enabled: root.flow !== null && root.flow.isResponseRequired
                        onClicked: {
                            if (!root.flow || !root.flow.isResponseRequired)
                                return;
                            root.flow.submit(password.text);
                            password.text = "";
                        }
                    }
                }
            }
        }

        SequentialAnimation {
            id: shake

            NumberAnimation { target: offset; property: "x"; to: -12; duration: 50 }
            NumberAnimation { target: offset; property: "x"; to: 10; duration: 80 }
            NumberAnimation { target: offset; property: "x"; to: -6; duration: 70 }
            NumberAnimation { target: offset; property: "x"; to: 0; duration: 60 }
        }
    }
}
