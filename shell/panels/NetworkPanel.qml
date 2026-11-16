pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.services

// The wired and Wi-Fi connections, NetworkManager's VPNs, Tailscale, and the networks nearby.
Card {
    id: root
    panel: "network"
    readonly property bool wifiReady: NetworkService.wifiOn && NetworkService.wifiDevice !== null
    readonly property bool connecting: NetworkService.connectingNetwork !== null && NetworkService.connectedWifi === null

    // Opening reads what NetworkManager already knows; only the refresh button scans.
    // It also looks for tailscaled, which may have started since.
    Component.onCompleted: {
        NetworkService.refreshList();
        TailscaleService.refresh();
    }

    headerActions: [
        HeaderButton {
            iconName: "refresh"
            visible: root.wifiReady
            busy: NetworkService.isScanning
            tooltipText: NetworkService.isScanning ? "Scanning for Wi-Fi networks…" : "Scan for Wi-Fi networks"
            onClicked: NetworkService.scan()
        },

        // On while every radio is off.
        HeaderButton {
            visible: RadioService.available
            iconName: "airplane"
            checked: RadioService.airplaneMode
            tooltipText: RadioService.airplaneMode ? "Turn airplane mode off" : "Turn airplane mode on"
            onClicked: RadioService.setAirplaneMode(!RadioService.airplaneMode)
        },

        HeaderButton {
            visible: NetworkService.wifiDevice !== null
            iconName: NetworkService.wifiOn ? "wifi" : "wifi-off"
            checked: NetworkService.wifiOn
            tooltipText: NetworkService.wifiOn ? "Turn Wi-Fi off" : "Turn Wi-Fi on"
            onClicked: NetworkService.setWifiEnabled(!NetworkService.wifiOn)
        }
    ]

    pinnedContent: [
        Notice {
            visible: RadioService.airplaneMode
            heading: "Airplane mode"
            detail: "Wi-Fi, Bluetooth, and mobile broadband are off."
            toneColor: Theme.accent
        },

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
            onActionTriggered: NetworkService.disconnectWifi()
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
                // Connect shows while hovered, as the row's click does it too.
                actions: {
                    if (vpnRow.connected && !vpnRow.busy)
                        return [{ text: "Disconnect", actionId: "disconnect" }];
                    if (vpnRow.failed && VpnService.errorCanRetry)
                        return [{ text: "Enter password", actionId: "retry" }];
                    if (vpnRow.hovered && !vpnRow.busy && !vpnRow.prompt)
                        return [{ text: "Connect", actionId: "connect" }];
                    return [];
                }
                onPrimaryTriggered: {
                    if (vpnRow.prompt)
                        VpnService.cancel();
                    else
                        VpnService.connect(vpnRow.modelData.uuid, false);
                }
                onActionTriggered: actionId => {
                    if (actionId === "retry" || actionId === "connect")
                        VpnService.connect(vpnRow.modelData.uuid, actionId === "retry");
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

        DeviceRow {
            visible: TailscaleService.available && TailscaleService.backendState !== ""
            title: "Tailscale"
            subtitle: TailscaleService.subtitle()
            iconName: "vpn"
            current: TailscaleService.connected
            busy: TailscaleService.switching && TailscaleService.authUrl === ""
            primaryEnabled: !TailscaleService.connected && !TailscaleService.switching
            actions: {
                if (TailscaleService.authUrl !== "")
                    return [{ text: "Open login", actionId: "login" }, { text: "Cancel", actionId: "cancel" }];
                if (TailscaleService.connected && !TailscaleService.switching)
                    return [{ text: "Disconnect", actionId: "disconnect" }];
                return [];
            }
            onPrimaryTriggered: TailscaleService.connect()
            onActionTriggered: actionId => {
                if (actionId === "login")
                    TailscaleService.openLogin();
                else if (actionId === "cancel")
                    TailscaleService.cancel();
                else
                    TailscaleService.disconnect();
            }

            Label {
                role: "caption"
                visible: TailscaleService.errorText !== ""
                width: parent.width
                text: TailscaleService.errorText
                color: Theme.error
                wrapMode: Text.WordWrap
            }
        },

        Label {
            visible: NetworkService.connectError !== ""
                && !NetworkService.displayedNetworks.some(item => item.name === NetworkService.connectErrorName)
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
                    primaryEnabled: !networkRow.modelData.stateChanging
                    actions: networkRow.modelData.network && !networkRow.modelData.stateChanging
                        ? [{ text: "Forget", kind: "danger", actionId: "forget" }]
                        : []
                    onPrimaryTriggered: NetworkService.activate(networkRow.modelData)
                    onActionTriggered: NetworkService.forget(networkRow.modelData)

                    Field {
                        visible: networkRow.prompting
                        placeholder: "Password"
                        masked: true
                        confirmText: "Connect"
                        autoFocus: true
                        // The draft goes with the prompt.
                        onVisibleChanged: if (!visible) text = ""
                        onAccepted: NetworkService.connectWithPassword(networkRow.modelData, text)
                        onCancelled: NetworkService.cancelPasswordPrompt()
                    }

                    Label {
                        role: "caption"
                        visible: NetworkService.connectErrorName === networkRow.modelData.name && NetworkService.connectError !== ""
                        width: parent.width
                        text: NetworkService.connectError
                        color: Theme.error
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // The heading says while it scans.
            Label {
                visible: NetworkService.displayedNetworks.length === 0 && !NetworkService.isScanning
                width: parent.width
                text: NetworkService.scannedAtMs > 0 ? "Nothing else is in range."
                    : "Scan from the header to see the networks around you."
                color: Theme.subtext
                wrapMode: Text.WordWrap
            }
        }
    ]
}
