pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.theme
import qs.services

// The wired and Wi-Fi connections, NetworkManager's VPNs, and the networks nearby.
Card {
    id: root
    title: "Network"
    iconName: "wifi"
    property bool presented: false
    readonly property bool wifiReady: NetworkService.wifiOn && NetworkService.wifiDevice !== null
    readonly property bool connecting: NetworkService.connectingNetwork !== null && NetworkService.connectedWifi === null

    // Scanning waits for the refresh button; closing the panel stops it.
    onPresentedChanged: if (!root.presented && NetworkService.isScanning) NetworkService.stopWifiScan()
    Component.onDestruction: if (NetworkService.isScanning) NetworkService.stopWifiScan()

    headerActions: Row {
        spacing: Theme.spacingSmall

        HeaderButton {
            iconName: "refresh"
            visible: root.wifiReady
            busy: root.presented && NetworkService.isScanning
            tooltipText: NetworkService.isScanning ? "Stop Wi-Fi scan" : "Scan for Wi-Fi networks"
            onClicked: NetworkService.toggleWifiScan()
        }

        ToggleSwitch {
            visible: NetworkService.wifiDevice !== null
            checked: NetworkService.wifiOn
            tooltipText: NetworkService.wifiOn ? "Turn Wi-Fi off" : "Turn Wi-Fi on"
            onToggled: function(state) { NetworkService.setWifiEnabled(state); }
        }
    }

    pinnedContent: [
        DeviceRow {
            visible: NetworkService.wiredDevice !== null
            title: NetworkService.wiredDevice ? NetworkService.wiredDevice.name : "Ethernet"
            subtitle: "Wired · Connected"
            iconName: "network-wired"
            current: true
            primaryEnabled: false
        },

        DeviceRow {
            visible: NetworkService.connectedWifi !== null
            title: NetworkService.connectedWifi ? NetworkService.connectedWifi.name : ""
            subtitle: NetworkService.connectedSubtitle()
            iconName: NetworkService.signalIcon(NetworkService.signalPercent(
                NetworkService.connectedWifi ? NetworkService.connectedWifi.signalStrength : 0))
            current: true
            primaryEnabled: false
            actions: [{ text: "Disconnect", actionId: "disconnect" }]
            onActionTriggered: {
                if (NetworkService.connectedWifi)
                    NetworkService.connectedWifi.disconnect();
            }
        },

        DeviceRow {
            visible: root.connecting
            title: NetworkService.connectingNetwork ? NetworkService.connectingNetwork.name : ""
            subtitle: "Connecting…"
            subtitleColor: Theme.accent
            busy: true
            primaryEnabled: false
        },

        Repeater {
            model: VpnService.connections
            delegate: DeviceRow {
                id: vpnRow
                required property var modelData
                readonly property bool connected: vpnRow.modelData.state === "activated"
                readonly property var prompt: VpnService.promptFor(vpnRow.modelData.uuid)
                readonly property bool failed: VpnService.errorUuid === vpnRow.modelData.uuid && VpnService.errorText !== ""

                title: vpnRow.modelData.name
                subtitle: VpnService.subtitle(vpnRow.modelData)
                iconName: "vpn"
                current: vpnRow.connected
                busy: VpnService.busy(vpnRow.modelData)
                primaryEnabled: !vpnRow.connected && !vpnRow.busy
                actions: {
                    if (vpnRow.connected && !vpnRow.busy)
                        return [{ text: "Disconnect", actionId: "disconnect" }];
                    if (vpnRow.failed && VpnService.errorCanRetry)
                        return [{ text: "Enter password", actionId: "retry" }];
                    return [];
                }
                onPrimaryTriggered: {
                    if (vpnRow.prompt)
                        VpnService.cancel();
                    else
                        VpnService.connect(vpnRow.modelData.uuid, false);
                }
                onActionTriggered: actionId => {
                    if (actionId === "retry")
                        VpnService.connect(vpnRow.modelData.uuid, true);
                    else
                        VpnService.disconnect(vpnRow.modelData.uuid);
                }

                Label {
                    role: "caption"
                    visible: !!vpnRow.prompt && vpnRow.prompt.message !== ""
                    width: parent.width
                    text: vpnRow.prompt ? vpnRow.prompt.message : ""
                    color: vpnRow.prompt && vpnRow.prompt.kind === "login" ? Theme.error : Theme.subtext
                    wrapMode: Text.WordWrap
                }

                Field {
                    id: vpnUser
                    visible: !!vpnRow.prompt && vpnRow.prompt.kind === "login" && vpnRow.prompt.needUser
                    placeholder: "Username"
                    autoFocus: true
                    onVisibleChanged: if (visible) text = vpnRow.prompt.user
                    onAccepted: vpnPassword.focusInput()
                    onCancelled: VpnService.cancel()
                }

                Field {
                    id: vpnPassword
                    visible: !!vpnRow.prompt && vpnRow.prompt.kind === "login"
                    placeholder: "Password"
                    masked: true
                    confirmText: "Connect"
                    autoFocus: !vpnUser.visible
                    onAccepted: VpnService.submitLogin(vpnUser.text, vpnPassword.text)
                    onCancelled: VpnService.cancel()
                }

                Field {
                    visible: !!vpnRow.prompt && vpnRow.prompt.kind === "question"
                    placeholder: vpnRow.prompt ? vpnRow.prompt.label : ""
                    masked: !!vpnRow.prompt && vpnRow.prompt.masked
                    confirmText: "Continue"
                    autoFocus: true
                    onAccepted: VpnService.answer(text)
                    onCancelled: VpnService.cancel()
                }

                Flow {
                    visible: !!vpnRow.prompt && vpnRow.prompt.kind === "choice"
                    width: parent.width
                    spacing: Theme.spacingTiny

                    Label {
                        height: choiceCancel.height
                        verticalAlignment: Text.AlignVCenter
                        text: vpnRow.prompt && vpnRow.prompt.kind === "choice" ? vpnRow.prompt.label : ""
                        color: Theme.subtext
                    }

                    Repeater {
                        model: vpnRow.prompt && vpnRow.prompt.kind === "choice" ? vpnRow.prompt.choices : []
                        delegate: ActionButton {
                            required property string modelData
                            text: modelData
                            compact: true
                            onClicked: VpnService.answer(modelData)
                        }
                    }

                    ActionButton {
                        id: choiceCancel
                        text: "Cancel"
                        compact: true
                        onClicked: VpnService.cancel()
                    }
                }

                Label {
                    role: "caption"
                    visible: vpnRow.failed
                    width: parent.width
                    text: VpnService.errorText
                    color: Theme.error
                    wrapMode: Text.WordWrap
                }
            }
        },

        Label {
            visible: NetworkService.connectError !== "" && NetworkService.passwordRowName === ""
            width: parent.width
            text: NetworkService.connectError
            color: Theme.error
            wrapMode: Text.WordWrap
        },

        EmptyState {
            visible: NetworkService.wifiDevice === null && NetworkService.wiredDevice === null
            iconName: "wifi-off"
            title: "No network adapter"
            detail: "No Wi-Fi or wired network device was found."
        },

        EmptyState {
            visible: NetworkService.wifiDevice !== null && !NetworkService.wifiOn
            iconName: "wifi-off"
            title: "Wi-Fi is off"
            detail: "Turn it on to see networks nearby."
            actionLabel: "Turn on Wi-Fi"
            actionIconName: "wifi"
            onActivated: NetworkService.setWifiEnabled(true)
        }
    ]

    content: [
        Column {
            visible: root.wifiReady
            width: parent.width
            spacing: Theme.spacingTiny

            DeviceSection {
                title: "Nearby"
                count: NetworkService.displayedNetworks.length
                status: NetworkService.nearbyStatusText()
                statusActive: NetworkService.isScanning
            }

            Item { width: 1; height: Theme.spacingTiny }

            Repeater {
                model: NetworkService.displayedNetworks
                delegate: DeviceRow {
                    id: networkRow
                    required property var modelData
                    readonly property bool prompting: NetworkService.passwordRowName === networkRow.modelData.name

                    title: networkRow.modelData.name
                    subtitle: NetworkService.networkSubtitle(networkRow.modelData)
                    iconName: NetworkService.signalIcon(networkRow.modelData.signalLevel)
                    busy: networkRow.modelData.stateChanging
                    primaryEnabled: networkRow.modelData.live && !networkRow.modelData.stateChanging
                    opacity: networkRow.modelData.live ? 1.0 : Theme.disabledOpacity
                    actions: networkRow.modelData.live && networkRow.modelData.known && networkRow.modelData.network
                        ? [{ text: "Forget", kind: "danger", actionId: "forget" }]
                        : []
                    onPrimaryTriggered: NetworkService.activate(networkRow.modelData)
                    onActionTriggered: {
                        if (networkRow.modelData.network)
                            networkRow.modelData.network.forget();
                    }

                    Field {
                        visible: networkRow.prompting
                        placeholder: "Password"
                        masked: true
                        confirmText: "Connect"
                        autoFocus: true
                        text: NetworkService.passwordText
                        onTextChanged: NetworkService.passwordText = text
                        onAccepted: NetworkService.connectWithPassword(networkRow.modelData, NetworkService.passwordText)
                        onCancelled: NetworkService.cancelPasswordPrompt()
                    }

                    Label {
                        role: "caption"
                        visible: networkRow.prompting && NetworkService.connectErrorName === networkRow.modelData.name
                        width: parent.width
                        text: NetworkService.connectError
                        color: Theme.error
                        wrapMode: Text.WordWrap
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animDuration }
                    }
                }
            }

            EmptyState {
                visible: NetworkService.displayedNetworks.length === 0
                iconName: "wifi"
                busy: NetworkService.isScanning
                title: NetworkService.isScanning ? "Looking for networks…"
                    : (NetworkService.scanRequested ? "No other networks found" : "No scan yet")
                detail: NetworkService.isScanning ? ""
                    : (NetworkService.scanRequested ? "Nothing else is in range right now." : "Scan to see the Wi-Fi networks around you.")
                actionLabel: NetworkService.isScanning ? "" : (NetworkService.scanRequested ? "Scan again" : "Scan")
                actionIconName: "refresh"
                onActivated: NetworkService.startWifiScan()
            }
        }
    ]
}
