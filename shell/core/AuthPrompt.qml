pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
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
            shake.play();
        }
    }

    ModalWindow {
        id: window

        targetScreen: root.targetScreen
        visible: agent.isActive && root.flow !== null && root.targetScreen !== null
        color: Theme.alpha(Theme.crust, 0.6)
        focusGrabActive: window.visible

        WlrLayershell.namespace: "speshell-auth"

        onVisibleChanged: {
            root.failures = 0;
            if (window.visible)
                password.focusInput();
        }

        Dialog {
            width: Theme.panelWidth + Theme.spacingXL * 2
            iconName: "lock"
            title: "Authentication required"
            detail: root.flow ? root.flow.message : ""
            transform: Translate { id: shakeOffset }

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

        Shake {
            id: shake
            offset: shakeOffset
        }
    }
}
