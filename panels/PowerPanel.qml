pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.services
import qs.theme

Card {
    id: root

    property bool presented: false

    title: "Power"
    iconName: "power"
    // The action waiting for a second click; empty when none is.
    property string pendingAction: ""

    readonly property var actions: [
        { id: "sleep", label: "Sleep", detail: "Lock and suspend", iconName: "sleep", tone: "info" },
        { id: "logout", label: "Log out", detail: "End this session", iconName: "logout", tone: "warning" },
        { id: "restart", label: "Restart", detail: "Reboot the system", iconName: "restart", tone: "warning" },
        { id: "poweroff", label: "Power off", detail: "Shut down", iconName: "power", tone: "error" }
    ]

    onPresentedChanged: if (!root.presented) root.cancelConfirmation()

    function canRun(action) {
        if (PowerService.busy)
            return false;
        if (action === "lock" || action === "sleep")
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

    component PowerTile: Rectangle {
        id: tile

        property string label: ""
        property string detail: ""
        property string iconName: ""
        property string tone: "accent"
        property bool pending: false
        property bool working: false
        property int countdownMs: 0

        readonly property color toneColor: Theme.toneColor(tile.tone)
        readonly property bool hot: tile.pending || (tileMouse.containsMouse && tile.enabled)

        signal activated()

        implicitHeight: Math.max(Theme.controlHeight, tileText.implicitHeight)
            + Theme.spacingMedium * 2
        radius: Theme.borderRadiusSmall
        clip: true
        opacity: tile.enabled ? 1.0 : Theme.disabledOpacity
        color: tile.pending
            ? Theme.alpha(tile.toneColor, Theme.tintStrong)
            : (tile.hot ? Theme.alpha(tile.toneColor, Theme.tintSubtle) : Theme.controlFill)
        border.width: Theme.borderWidth
        border.color: tile.pending
            ? Theme.alpha(tile.toneColor, Theme.tintOutlineStrong)
            : (tile.hot ? Theme.alpha(tile.toneColor, Theme.tintOutline) : "transparent")

        Behavior on color {
            ColorAnimation { duration: Theme.animDurationFast }
        }

        Accessible.role: Accessible.Button
        Accessible.name: tile.label
        Accessible.description: tile.pending ? "Press again to confirm" : tile.detail
        Accessible.onPressAction: if (tile.enabled) tile.activated()

        Rectangle {
            id: disc
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingMedium
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.controlHeight
            height: width
            radius: width / 2
            color: Theme.alpha(tile.hot ? tile.toneColor : Theme.overlay,
                tile.hot ? Theme.tintStrong : Theme.tintSubtle)

            AppIcon {
                anchors.centerIn: parent
                name: tile.iconName
                size: Theme.iconSizeMedium
                iconColor: tile.hot ? tile.toneColor : Theme.subtextBright
            }
        }

        Column {
            id: tileText
            anchors.left: disc.right
            anchors.leftMargin: Theme.spacingSmall
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingMicro

            Text {
                width: parent.width
                text: tile.working ? "Working…" : (tile.pending ? tile.label + "?" : tile.label)
                color: Theme.text
                font.pixelSize: Theme.fontSizeNormal
                font.family: Theme.fontFamily
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: tile.pending ? "Click again to confirm" : tile.detail
                color: tile.pending ? tile.toneColor : Theme.subtext
                font.pixelSize: Theme.fontSizeCaption
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }
        }

        // Drains while the confirmation waits.
        Rectangle {
            id: countdown
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            height: 2
            color: tile.toneColor
            visible: tile.pending

            NumberAnimation on width {
                running: tile.pending
                from: tile.width
                to: 0
                duration: tile.countdownMs
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            enabled: tile.enabled
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: tile.activated()
        }
    }

    PowerTile {
        width: parent.width
        label: "Lock screen"
        detail: PowerService.lockerChecking
            ? "Checking screen locker"
            : (PowerService.lockerAvailable ? "Secure this session" : "Screen locker unavailable")
        iconName: "lock"
        enabled: root.canRun("lock")
        working: PowerService.activeAction === "lock"
        onActivated: {
            root.cancelConfirmation();
            PowerService.runAction("lock");
        }
    }

    Grid {
        id: actionGrid
        width: parent.width
        columns: 2
        spacing: Theme.spacingSmall

        Repeater {
            model: root.actions

            delegate: PowerTile {
                required property var modelData

                width: (actionGrid.width - actionGrid.spacing) / 2
                label: modelData.label
                detail: modelData.detail
                iconName: modelData.iconName
                tone: modelData.tone
                enabled: root.canRun(modelData.id)
                pending: root.pendingAction === modelData.id
                working: PowerService.activeAction === modelData.id
                countdownMs: confirmationTimer.interval
                onActivated: root.activate(modelData.id)
            }
        }
    }

    Text {
        visible: PowerService.errorMessage !== ""
        width: parent.width
        text: PowerService.errorMessage
        color: Theme.error
        font.pixelSize: Theme.fontSizeSmall
        font.family: Theme.fontFamily
        wrapMode: Text.WordWrap
    }
}
