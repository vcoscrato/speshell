pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.services
import qs.theme

// Lock, Keep awake, and the session's power actions, each asking for a second click.
Card {
    id: root

    property bool presented: false

    title: "Power"
    iconName: "power"
    // The action waiting for a second click; empty when none is.
    property string pendingAction: ""

    readonly property var actions: [
        { id: "sleep", label: "Sleep", detail: "Lock and suspend", iconName: "sleep", tone: "accent" },
        { id: "hibernate", label: "Hibernate", detail: "Lock and save to disk", iconName: "hibernate", tone: "accent" },
        { id: "logout", label: "Log out", detail: "End this session", iconName: "logout", tone: "warning" },
        { id: "restart", label: "Restart", detail: "Reboot the system", iconName: "restart", tone: "warning" },
        { id: "poweroff", label: "Power off", detail: "Shut down", iconName: "power", tone: "error" }
    ]

    onPresentedChanged: if (!root.presented) root.cancelConfirmation()

    function canRun(action) {
        if (PowerService.busy)
            return false;
        if (action === "lock" || PowerService.sleeps(action))
            return PowerService.lockerAvailable;
        return true;
    }

    // The first click arms an action; a second click within the countdown runs it.
    function activate(action) {
        if (!root.canRun(action))
            return;
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

    ActionTile {
        width: parent.width
        label: PowerService.activeAction === "lock" ? "Working…" : "Lock screen"
        detail: PowerService.lockerChecking
            ? "Checking screen locker"
            : (PowerService.lockerAvailable ? "Secure this session" : "Screen locker unavailable")
        iconName: "lock"
        enabled: root.canRun("lock")
        onActivated: {
            root.cancelConfirmation();
            PowerService.runAction("lock");
        }
    }

    ActionTile {
        width: parent.width
        label: "Keep awake"
        detail: IdleService.keepAwake ? "On until you turn it off: nothing dims, locks, or sleeps"
            : "Hold off dimming, locking, and sleeping on idle"
        iconName: "awake"
        active: IdleService.keepAwake
        onActivated: {
            root.cancelConfirmation();
            IdleService.setKeepAwake(!IdleService.keepAwake);
        }
    }

    // Two to a row; with an odd count, the last takes a row to itself.
    Flow {
        id: actionGrid

        readonly property var shown: root.actions.filter(action => action.id !== "hibernate" || PowerService.canHibernate)

        width: parent.width
        spacing: Theme.spacingSmall

        Repeater {
            model: actionGrid.shown

            delegate: ActionTile {
                id: tile

                required property var modelData
                required property int index
                readonly property bool pending: root.pendingAction === tile.modelData.id
                readonly property bool alone: tile.index === actionGrid.shown.length - 1 && actionGrid.shown.length % 2 === 1

                width: tile.alone ? actionGrid.width : (actionGrid.width - actionGrid.spacing) / 2
                label: PowerService.activeAction === tile.modelData.id ? "Working…"
                    : tile.pending ? tile.modelData.label + "?" : tile.modelData.label
                detail: tile.pending ? "Click again to confirm" : tile.modelData.detail
                iconName: tile.modelData.iconName
                tone: tile.modelData.tone
                enabled: root.canRun(tile.modelData.id)
                active: tile.pending
                countdownMs: confirmationTimer.interval
                onActivated: root.activate(tile.modelData.id)
            }
        }
    }

    Label {
        visible: PowerService.errorMessage !== ""
        width: parent.width
        text: PowerService.errorMessage
        color: Theme.error
        wrapMode: Text.WordWrap
    }
}
