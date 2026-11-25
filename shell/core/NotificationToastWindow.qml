pragma ComponentBehavior: Bound
// Quickshell's type info marks PanelWindow uncreatable, though QML creates it.
// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import qs.services
import qs.components

// Toasts in the focused screen's right corner across from the bar, clear of the
// dropdowns that hang from it: the oldest in the corner, each newer one toward the bar,
// so those already shown keep still as others come. They pop in, fade out, and the rest
// close up behind.
PanelWindow {
    id: root

    property var targetScreen: HyprlandService.focusedScreen()
    readonly property bool atTop: ConfigService.settings.bar.position === "bottom"
    // The toasts' height, held while one fades out so the window doesn't cut it off.
    property real heldHeight: 0

    // Each new toast opens on the focused monitor.
    Connections {
        target: NotificationService

        function onPopupCounterChanged() {
            root.targetScreen = HyprlandService.focusedScreen();
        }
    }

    screen: root.targetScreen

    // Never takes focus, so toasts can't steal it from games and other apps.
    focusable: false
    // Clear of the bar, which reserves its edge.
    exclusionMode: ExclusionMode.Normal

    anchors {
        top: root.atTop
        bottom: !root.atTop
        right: true
    }

    // Quickshell's type info hides the fields of PanelWindow.margins.
    // qmllint disable missing-property
    margins {
        top: Theme.spacingXL
        bottom: Theme.spacingXL
        right: Theme.spacingXL
    }
    // qmllint enable missing-property

    color: "transparent"
    implicitWidth: Theme.toastWidth
    implicitHeight: Math.max(1, root.heldHeight)
    // Mapped as soon as a toast comes, since the list lays out only in a window.
    visible: NotificationService.activePopups.length > 0 || root.heldHeight > 0

    // Grows at once for a toast that comes, and shrinks once one that went has faded.
    Connections {
        target: toastList

        function onContentHeightChanged() {
            if (toastList.contentHeight >= root.heldHeight)
                root.heldHeight = toastList.contentHeight;
            else
                shrinkTimer.restart();
        }
    }

    Timer {
        id: shrinkTimer
        interval: Math.max(Theme.animDurationExit, Theme.animDuration)
        onTriggered: root.heldHeight = toastList.contentHeight
    }

    ListView {
        id: toastList
        anchors.fill: parent
        spacing: Theme.spacingMedium
        interactive: false
        // From the corner toward the bar.
        verticalLayoutDirection: root.atTop ? ListView.TopToBottom : ListView.BottomToTop
        // Keyed by popupId, so a toast that comes or goes leaves the others' delegates be.
        model: ScriptModel {
            values: NotificationService.activePopups
            objectProp: "popupId"
        }

        // The pointer on any toast holds them all, so one can be read to the end.
        HoverHandler {
            onHoveredChanged: NotificationService.setPopupsHeld(hovered)
        }

        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animDuration; easing.type: Theme.animEasing }
            NumberAnimation { property: "scale"; from: Theme.popScale; to: 1; duration: Theme.animDuration; easing.type: Theme.animEasingPop }
        }

        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: Theme.animDurationExit; easing.type: Theme.animEasingExit }
            NumberAnimation { property: "scale"; to: Theme.popScale; duration: Theme.animDurationExit; easing.type: Theme.animEasingExit }
        }

        displaced: Transition {
            NumberAnimation { property: "y"; duration: Theme.animDuration; easing.type: Theme.animEasing }
            // Whole again, should it move while coming in.
            NumberAnimation { properties: "opacity,scale"; to: 1; duration: Theme.animDuration; easing.type: Theme.animEasing }
        }

        delegate: Item {
            id: toastCard
            required property var modelData
            // Replaced notifications update the live object in place. It closes before
            // the toast fades out and goes then, so the copy shows from its close on.
            property var live: modelData.notification
            // What it says now.
            readonly property var shown: toastCard.live ?? toastCard.modelData
            readonly property color toneColor: modelData.urgency === 2 ? Theme.error : Theme.accent
            // What is left of its time on screen, from 1 to 0.
            property real remaining: 1
            // Whether it closes on its own, rather than when dismissed.
            property bool timed: false

            // Runs from the time left, as when a replaced notification restarts it.
            // modelData is a copy, so the expiry the service moves is read from it.
            function startCountdown() {
                const popup = NotificationService.popupById(toastCard.modelData.popupId);
                countdown.stop();
                if (!popup)
                    return;
                const duration = Number(popup.duration);
                const left = Number(popup.expiresAt) - Date.now();
                toastCard.timed = duration > 0 && popup.expiresAt >= 0;
                if (!toastCard.timed)
                    return;
                toastCard.remaining = Math.max(0, Math.min(1, left / duration));
                countdown.duration = Math.max(0, left);
                if (!NotificationService.popupsHeld)
                    countdown.start();
            }

            NumberAnimation {
                id: countdown
                target: toastCard
                property: "remaining"
                to: 0
            }

            // The service resets the expiry first, so read it after.
            Connections {
                target: toastCard.live
                function onSummaryChanged() { Qt.callLater(toastCard.startCountdown); }
                function onBodyChanged() { Qt.callLater(toastCard.startCountdown); }
                function onClosed() { toastCard.live = null; }
            }

            // Holds while the pointer rests on the toasts, and goes on from the expiry
            // the service moved on.
            Connections {
                target: NotificationService
                function onPopupsHeldChanged() {
                    if (NotificationService.popupsHeld)
                        countdown.stop();
                    else
                        toastCard.startCountdown();
                }
            }

            width: ListView.view.width
            // Room below the content for the countdown.
            height: toastContent.height + Theme.spacingLarge + Theme.spacingMedium + Theme.spacingSmall

            // In a right corner: rounded toward the screen's center, accent edge on the left.
            Surface {
                anchors.fill: parent
                backdrop: true
                roundBottomLeft: root.atTop
                roundTopLeft: !root.atTop
                edge: "left"
                edgeColor: toastCard.toneColor
                tint: toastMouse.containsMouse ? Theme.controlFill : "transparent"

                Behavior on tint {
                    ColorAnimation { duration: Theme.animDuration }
                }
            }

            Component.onCompleted: toastCard.startCountdown()

            // A click runs the default action and goes to the app, and dismisses the toast.
            MouseArea {
                id: toastMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: toastCard.modelData.defaultAction || NotificationService.entryOf(toastCard.modelData)
                    ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: NotificationService.activatePopup(toastCard.modelData.popupId)
            }

            Column {
                id: toastContent
                anchors {
                    left: parent.left
                    right: dismissBtn.left
                    top: parent.top
                    margins: Theme.spacingMedium
                    topMargin: Theme.spacingLarge
                    leftMargin: Theme.spacingLarge
                }
                spacing: Theme.spacingSmall

                Row {
                    spacing: Theme.spacingSmall

                    NotificationIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        notification: toastCard.modelData
                    }

                    Label {
                        role: "section"
                        text: toastCard.modelData.appName || "App"
                        anchors.verticalCenter: parent.verticalCenter
                        color: toastCard.toneColor
                    }
                }

                Label {
                    role: "title"
                    text: NotificationService.summaryText(toastCard.shown)
                    width: parent.width
                    elide: Text.ElideRight
                    visible: text !== ""
                }

                Label {
                    text: NotificationService.bodyText(toastCard.shown)
                    color: Theme.subtext
                    width: parent.width
                    elide: Text.ElideRight
                    maximumLineCount: 3
                    wrapMode: Text.WordWrap
                    visible: text !== ""
                }

                Flow {
                    width: parent.width
                    spacing: Theme.spacingSmall
                    visible: toastCard.modelData.actions.length > 0

                    Repeater {
                        model: toastCard.modelData.actions
                        delegate: ActionButton {
                            required property var modelData
                            text: modelData.text
                            compact: true
                            onClicked: NotificationService.invokePopupAction(
                                toastCard.modelData.popupId,
                                modelData.action
                            )
                        }
                    }
                }
            }

            // Drains toward the left until the toast closes on its own.
            ProgressBar {
                visible: toastCard.timed
                anchors {
                    left: toastContent.left
                    right: parent.right
                    bottom: parent.bottom
                    rightMargin: Theme.spacingMedium
                    bottomMargin: Theme.spacingSmall
                }
                height: Theme.spacingMicro
                value: toastCard.remaining
                fillColor: Theme.alpha(toastCard.toneColor, Theme.tintOutline)
            }

            IconButton {
                id: dismissBtn
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingSmall
                anchors.top: parent.top
                anchors.topMargin: Theme.spacingMedium
                iconName: "close"
                size: Theme.controlHeightSmall
                iconSize: Theme.iconSizeSmall
                iconColor: containsMouse ? Theme.error : Theme.overlay
                hoverColor: Theme.alpha(Theme.error, Theme.tintStrong)
                tooltipText: "Dismiss notification"
                onClicked: NotificationService.dismissPopup(toastCard.modelData.popupId)
            }
        }
    }
}
