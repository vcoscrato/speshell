pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.theme
import qs.services

Card {
    id: root
    title: "Network"
    iconName: "wifi"
    property bool presented: false
    readonly property var network: NetworkService
    readonly property var vpn: VpnService
    readonly property bool wifiReady: root.network.wifiOn && root.network.wifiDevice !== null
    readonly property bool connecting: root.network.connectingNetwork !== null && root.network.connectedWifi === null

    // Scanning waits for the refresh button; closing the panel stops it.
    onPresentedChanged: if (!root.presented && root.network.isScanning) root.network.stopWifiScan()
    Component.onDestruction: if (root.network.isScanning) root.network.stopWifiScan()

    headerActions: Row {
        spacing: Theme.spacingSmall

        RefreshButton {
            visible: root.wifiReady
            active: root.presented && root.network.isScanning
            tooltipText: root.network.isScanning ? "Stop Wi-Fi scan" : "Scan for Wi-Fi networks"
            onClicked: root.network.toggleWifiScan()
        }

        ToggleSwitch {
            visible: root.network.wifiDevice !== null
            checked: root.network.wifiOn
            tooltipText: root.network.wifiOn ? "Turn Wi-Fi off" : "Turn Wi-Fi on"
            onToggled: function(state) { root.network.setWifiEnabled(state); }
        }
    }

    pinnedContent: [
        DeviceRow {
            visible: root.network.wiredDevice !== null
            title: root.network.wiredDevice ? root.network.wiredDevice.name : "Ethernet"
            subtitle: "Wired · Connected"
            iconName: "network-wired"
            current: true
            primaryEnabled: false
        },

        DeviceRow {
            visible: root.network.connectedWifi !== null
            title: root.network.connectedWifi ? root.network.connectedWifi.name : ""
            subtitle: root.network.connectedSubtitle()
            iconName: root.network.signalIcon(root.network.signalPercent(
                root.network.connectedWifi ? root.network.connectedWifi.signalStrength : 0))
            current: true
            primaryEnabled: false
            actions: [{ text: "Disconnect", actionId: "disconnect" }]
            onActionTriggered: {
                if (root.network.connectedWifi)
                    root.network.connectedWifi.disconnect();
            }
        },

        DeviceRow {
            visible: root.connecting
            title: root.network.connectingNetwork ? root.network.connectingNetwork.name : ""
            subtitle: "Connecting…"
            subtitleColor: Theme.accent
            busy: true
            primaryEnabled: false
        },

        Repeater {
            model: root.vpn.connections
            delegate: DeviceRow {
                id: vpnRow
                required property var modelData
                readonly property bool connected: vpnRow.modelData.state === "activated"
                readonly property var prompt: root.vpn.promptFor(vpnRow.modelData.uuid)
                readonly property bool failed: root.vpn.errorUuid === vpnRow.modelData.uuid && root.vpn.errorText !== ""

                title: vpnRow.modelData.name
                subtitle: root.vpn.subtitle(vpnRow.modelData)
                iconName: "vpn"
                current: vpnRow.connected
                busy: root.vpn.busy(vpnRow.modelData)
                primaryEnabled: !vpnRow.connected && !vpnRow.busy
                actions: {
                    if (vpnRow.connected && !vpnRow.busy)
                        return [{ text: "Disconnect", actionId: "disconnect" }];
                    if (vpnRow.failed && root.vpn.errorCanRetry)
                        return [{ text: "Enter password", actionId: "retry" }];
                    return [];
                }
                onPrimaryTriggered: {
                    if (vpnRow.prompt)
                        root.vpn.cancel();
                    else
                        root.vpn.connect(vpnRow.modelData.uuid, false);
                }
                onActionTriggered: actionId => {
                    if (actionId === "retry")
                        root.vpn.connect(vpnRow.modelData.uuid, true);
                    else
                        root.vpn.disconnect(vpnRow.modelData.uuid);
                }

                Text {
                    visible: !!vpnRow.prompt && vpnRow.prompt.message !== ""
                    width: parent.width
                    text: vpnRow.prompt ? vpnRow.prompt.message : ""
                    font.pixelSize: Theme.fontSizeCaption
                    font.family: Theme.fontFamily
                    color: vpnRow.prompt && vpnRow.prompt.kind === "login" ? Theme.error : Theme.subtext
                    wrapMode: Text.WordWrap
                }

                InlinePrompt {
                    id: vpnUser
                    visible: !!vpnRow.prompt && vpnRow.prompt.kind === "login" && vpnRow.prompt.needUser
                    placeholder: "Username"
                    masked: false
                    showActions: false
                    onVisibleChanged: if (visible) text = vpnRow.prompt.user
                    onAccepted: vpnPassword.focusInput()
                    onCancelled: root.vpn.cancel()
                }

                InlinePrompt {
                    id: vpnPassword
                    visible: !!vpnRow.prompt && vpnRow.prompt.kind === "login"
                    autoFocus: !vpnUser.visible
                    onAccepted: root.vpn.submitLogin(vpnUser.text, vpnPassword.text)
                    onCancelled: root.vpn.cancel()
                }

                InlinePrompt {
                    visible: !!vpnRow.prompt && vpnRow.prompt.kind === "question"
                    placeholder: vpnRow.prompt ? vpnRow.prompt.label : ""
                    masked: !!vpnRow.prompt && vpnRow.prompt.masked
                    onAccepted: root.vpn.answer(text)
                    onCancelled: root.vpn.cancel()
                }

                Flow {
                    visible: !!vpnRow.prompt && vpnRow.prompt.kind === "choice"
                    width: parent.width
                    spacing: Theme.spacingTiny

                    Text {
                        height: choiceCancel.height
                        verticalAlignment: Text.AlignVCenter
                        text: vpnRow.prompt && vpnRow.prompt.kind === "choice" ? vpnRow.prompt.label : ""
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        color: Theme.subtext
                    }

                    Repeater {
                        model: vpnRow.prompt && vpnRow.prompt.kind === "choice" ? vpnRow.prompt.choices : []
                        delegate: ActionButton {
                            required property string modelData
                            text: modelData
                            compact: true
                            onClicked: root.vpn.answer(modelData)
                        }
                    }

                    ActionButton {
                        id: choiceCancel
                        text: "Cancel"
                        compact: true
                        onClicked: root.vpn.cancel()
                    }
                }

                Text {
                    visible: vpnRow.failed
                    width: parent.width
                    text: root.vpn.errorText
                    font.pixelSize: Theme.fontSizeCaption
                    font.family: Theme.fontFamily
                    color: Theme.error
                    wrapMode: Text.WordWrap
                }
            }
        },

        Text {
            visible: root.network.connectError !== "" && root.network.passwordRowName === ""
            width: parent.width
            text: root.network.connectError
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            color: Theme.error
            wrapMode: Text.WordWrap
        },

        EmptyState {
            visible: root.network.wifiDevice === null && root.network.wiredDevice === null
            iconName: "wifi-off"
            title: "No network adapter"
            detail: "No Wi-Fi or wired network device was found."
        },

        EmptyState {
            visible: root.network.wifiDevice !== null && !root.network.wifiOn
            iconName: "wifi-off"
            title: "Wi-Fi is off"
            detail: "Turn it on to see networks nearby."
            actionLabel: "Turn on Wi-Fi"
            actionIconName: "wifi"
            onActivated: root.network.setWifiEnabled(true)
        }
    ]

    content: [
        Column {
            visible: root.wifiReady
            width: parent.width
            spacing: Theme.spacingTiny

            DeviceSection {
                title: "Nearby"
                count: root.network.displayedNetworks.length
                status: root.network.nearbyStatusText()
                statusActive: root.network.isScanning
            }

            Item { width: 1; height: Theme.spacingTiny }

            Repeater {
                model: root.network.displayedNetworks
                delegate: DeviceRow {
                    id: networkRow
                    required property var modelData
                    readonly property bool prompting: root.network.passwordRowName === networkRow.modelData.name

                    title: networkRow.modelData.name
                    subtitle: root.network.networkSubtitle(networkRow.modelData)
                    iconName: root.network.signalIcon(networkRow.modelData.signalLevel)
                    busy: networkRow.modelData.stateChanging
                    primaryEnabled: networkRow.modelData.live && !networkRow.modelData.stateChanging
                    opacity: networkRow.modelData.live ? 1.0 : Theme.disabledOpacity
                    actions: networkRow.modelData.live && networkRow.modelData.known && networkRow.modelData.network
                        ? [{ text: "Forget", kind: "danger", actionId: "forget" }]
                        : []
                    onPrimaryTriggered: root.network.onNetworkItemPrimary(networkRow.modelData)
                    onActionTriggered: {
                        if (networkRow.modelData.network)
                            networkRow.modelData.network.forget();
                    }

                    InlinePrompt {
                        visible: networkRow.prompting
                        text: root.network.passwordText
                        onTextChanged: root.network.passwordText = text
                        onAccepted: root.network.requestConnectForItem(networkRow.modelData, root.network.passwordText)
                        onCancelled: root.network.cancelPasswordPrompt()
                    }

                    Text {
                        visible: networkRow.prompting && root.network.connectErrorName === networkRow.modelData.name
                        width: parent.width
                        text: root.network.connectError
                        font.pixelSize: Theme.fontSizeCaption
                        font.family: Theme.fontFamily
                        color: Theme.error
                        wrapMode: Text.WordWrap
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.animDuration }
                    }
                }
            }

            EmptyState {
                visible: root.network.displayedNetworks.length === 0
                iconName: "wifi"
                busy: root.network.isScanning
                title: root.network.isScanning ? "Looking for networks…"
                    : (root.network.scanRequested ? "No other networks found" : "No scan yet")
                detail: root.network.isScanning ? ""
                    : (root.network.scanRequested ? "Nothing else is in range right now." : "Scan to see the Wi-Fi networks around you.")
                actionLabel: root.network.isScanning ? "" : (root.network.scanRequested ? "Scan again" : "Scan")
                actionIconName: "refresh"
                onActivated: root.network.startWifiScan()
            }
        }
    ]
}
