pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.services

// Lock, which runs at once, and the session's power actions, each asking for a second
// click; Speshell's config and relaunch in the header; and, without a battery, the
// power mode.
Card {
    id: root

    property bool presented: false

    panel: "power"
    // The action waiting for a second click; empty when none is.
    property string pendingAction: ""

    // In two rows: what leaves the session waiting, and what ends it.
    readonly property var rows: [["lock", "sleep", "hibernate"], ["logout", "restart", "poweroff"]]

    headerActions: Row {
        spacing: Theme.spacingTiny

        HeaderButton {
            iconName: "config"
            tooltipText: "Edit config.ini"
            onClicked: ConfigService.openConfig()
        }

        HeaderButton {
            iconName: "refresh"
            busy: SystemState.relaunching
            enabled: SystemState.canRelaunch
            tooltipText: "Relaunch Speshell " + SystemState.appVersion
            onClicked: SystemState.relaunch()
        }
    }

    onPresentedChanged: if (!root.presented) root.cancelConfirmation()

    // Lock runs at once. Otherwise the first click arms an action, and a second click
    // within the countdown runs it.
    function activate(action) {
        if (PowerService.busy)
            return;
        if (action === "lock") {
            root.cancelConfirmation();
            PowerService.runAction(action);
            return;
        }
        if (root.pendingAction !== action) {
            root.pendingAction = action;
            confirmationTimer.restart();
            return;
        }
        // A double-click arms and confirms in one gesture; let it only arm.
        if (confirmationTimer.elapsedMs() < 400)
            return;
        root.cancelConfirmation();
        PowerService.runAction(action);
    }

    function cancelConfirmation() {
        confirmationTimer.stop();
        root.pendingAction = "";
    }

    Timer {
        id: confirmationTimer

        property double startedAt: 0

        function elapsedMs() {
            return Date.now() - confirmationTimer.startedAt;
        }

        interval: 5000
        onRunningChanged: if (running) startedAt = Date.now()
        onTriggered: root.pendingAction = ""
    }

    Repeater {
        model: root.rows

        delegate: Row {
            id: row

            required property var modelData
            readonly property var shown: row.modelData.filter(action => action !== "hibernate" || SessionService.canHibernate)

            width: parent.width
            spacing: Theme.spacingSmall

            Repeater {
                model: row.shown

                delegate: ActionTile {
                    id: tile

                    required property string modelData
                    readonly property var action: PowerService.actions[tile.modelData]
                    readonly property bool pending: root.pendingAction === tile.modelData

                    width: (row.width - row.spacing * (row.shown.length - 1)) / row.shown.length
                    stacked: true
                    label: PowerService.activeAction === tile.modelData ? "Working…"
                        : tile.pending ? tile.action.label + "?" : tile.action.label
                    iconName: tile.action.icon
                    tone: tile.action.tone
                    enabled: !PowerService.busy
                    active: tile.pending
                    countdownMs: confirmationTimer.interval
                    onActivated: root.activate(tile.modelData)
                }
            }
        }
    }

    Label {
        visible: PowerService.errorMessage === "" && text !== ""
        width: parent.width
        role: "caption"
        horizontalAlignment: Text.AlignHCenter
        text: root.pendingAction !== "" ? "Click again to confirm" : ""
        color: Theme.toneColor("warning")
    }

    Label {
        visible: PowerService.errorMessage !== ""
        width: parent.width
        text: PowerService.errorMessage
        color: Theme.error
        wrapMode: Text.WordWrap
    }

    // A laptop picks it in the Battery panel.
    PowerModeRow {
        visible: !FeatureSupport.supportsBattery
    }
}
