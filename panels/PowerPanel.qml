pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.services
import qs.theme

// Lock, which runs at once, and the session's power actions, each asking for a second
// click; Speshell's config and relaunch in the header; and, without a battery, the
// power mode.
Card {
    id: root

    property bool presented: false

    title: "Power"
    iconName: "power"
    // The action waiting for a second click; empty when none is.
    property string pendingAction: ""

    // In two rows: what leaves the session waiting, and what ends it.
    readonly property var rows: [
        [
            { id: "lock", label: "Lock", iconName: "lock", tone: "accent" },
            { id: "sleep", label: "Sleep", iconName: "sleep", tone: "accent" },
            { id: "hibernate", label: "Hibernate", iconName: "hibernate", tone: "accent" }
        ],
        [
            { id: "logout", label: "Log out", iconName: "logout", tone: "warning" },
            { id: "restart", label: "Restart", iconName: "restart", tone: "warning" },
            { id: "poweroff", label: "Power off", iconName: "power", tone: "error" }
        ]
    ]
    readonly property var modeOptions: [
        { value: "saver", label: "Saver" },
        { value: "balanced", label: "Balanced" },
        { value: "maximum", label: "Maximum" }
    ]

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

    function canRun(action) {
        if (PowerService.busy)
            return false;
        if (action === "lock" || PowerService.sleeps(action))
            return PowerService.lockerAvailable;
        return true;
    }

    // Lock runs at once. Otherwise the first click arms an action, and a second click
    // within the countdown runs it.
    function activate(action) {
        if (!root.canRun(action))
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
            readonly property var shown: row.modelData.filter(action => action.id !== "hibernate" || PowerService.canHibernate)

            width: parent.width
            spacing: Theme.spacingSmall

            Repeater {
                model: row.shown

                delegate: ActionTile {
                    id: tile

                    required property var modelData
                    readonly property bool pending: root.pendingAction === tile.modelData.id

                    width: (row.width - row.spacing * (row.shown.length - 1)) / row.shown.length
                    stacked: true
                    label: PowerService.activeAction === tile.modelData.id ? "Working…"
                        : tile.pending ? tile.modelData.label + "?" : tile.modelData.label
                    iconName: tile.modelData.iconName
                    tone: tile.modelData.tone
                    enabled: root.canRun(tile.modelData.id)
                    active: tile.pending
                    countdownMs: confirmationTimer.interval
                    onActivated: root.activate(tile.modelData.id)
                }
            }
        }
    }

    Label {
        visible: PowerService.errorMessage === "" && text !== ""
        width: parent.width
        role: "caption"
        horizontalAlignment: Text.AlignHCenter
        text: root.pendingAction !== "" ? "Click again to confirm"
            : PowerService.lockerChecking || PowerService.lockerAvailable ? ""
            : "No screen locker: lock, sleep, and hibernate are off"
        color: root.pendingAction !== "" ? Theme.toneColor("warning") : Theme.subtext
    }

    Label {
        visible: PowerService.errorMessage !== ""
        width: parent.width
        text: PowerService.errorMessage
        color: Theme.error
        wrapMode: Text.WordWrap
    }

    // A laptop picks it in the Battery panel.
    SettingRow {
        visible: !FeatureSupport.supportsBattery
        label: "Power mode"
        info: PowerService.profilesAvailable
            ? "Sets the system's power profile and Speshell's animations together."
            : "Sets how much Speshell animates."

        SegmentedControl {
            options: root.modeOptions
            currentValue: PowerService.mode
            onValueSelected: value => PowerService.setMode(value)
        }
    }
}
