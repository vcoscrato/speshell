pragma ComponentBehavior: Bound
// Quickshell's type info marks PanelWindow uncreatable, though QML creates it.
// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components

// Toasts in the focused screen's right corner across from the bar, clear of the
// dropdowns that hang from it.
PanelWindow {
    id: root

    property var targetScreen: HyprlandService.focusedScreen()
    readonly property bool atTop: ConfigService.settings.bar.position === "bottom"

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
    implicitWidth: 400
    implicitHeight: toastColumn.height
    visible: NotificationService.activePopups.length > 0

    Column {
        id: toastColumn
        width: parent.width
        spacing: Theme.spacingMedium

        // The pointer on any toast holds them all, so one can be read to the end.
        HoverHandler {
            onHoveredChanged: NotificationService.setPopupsHeld(hovered)
        }

        Repeater {
            model: NotificationService.activePopups

            delegate: Item {
                id: toastCard
                required property var modelData
                // Replaced notifications update the live object in place.
                readonly property var live: modelData.notification
                readonly property bool internal: String(modelData.id).indexOf("internal:") === 0
                readonly property string notificationIcon: modelData.image || (
                    modelData.appIcon ? Quickshell.iconPath(modelData.appIcon, true) : ""
                )
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

                width: parent.width
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

                // Pops in as the OSD does.
                scale: 0.96
                opacity: 0
                Component.onCompleted: {
                    entranceAnim.start();
                    toastCard.startCountdown();
                }

                ParallelAnimation {
                    id: entranceAnim
                    NumberAnimation { target: toastCard; property: "scale"; to: 1.0; duration: Theme.animDuration; easing.type: Theme.animEasing }
                    NumberAnimation { target: toastCard; property: "opacity"; to: 1.0; duration: Theme.animDuration }
                }

                // A click runs the default action, or opens the app, and dismisses the toast.
                MouseArea {
                    id: toastMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: toastCard.modelData.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
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

                        Image {
                            width: Theme.iconSizeMedium
                            height: Theme.iconSizeMedium
                            anchors.verticalCenter: parent.verticalCenter
                            visible: toastCard.notificationIcon !== ""
                            source: toastCard.notificationIcon
                            sourceSize: Qt.size(32, 32)
                            fillMode: Image.PreserveAspectFit
                        }

                        SpeshellMark {
                            size: Theme.iconSizeMedium
                            anchors.verticalCenter: parent.verticalCenter
                            visible: toastCard.internal && toastCard.notificationIcon === ""
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
                        text: (toastCard.live ? toastCard.live.summary : toastCard.modelData.summary) || ""
                        width: parent.width
                        elide: Text.ElideRight
                        visible: text !== ""
                    }

                    Label {
                        text: (toastCard.live ? toastCard.live.body : toastCard.modelData.body) || ""
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
                Rectangle {
                    visible: toastCard.timed
                    anchors {
                        left: toastContent.left
                        right: parent.right
                        bottom: parent.bottom
                        rightMargin: Theme.spacingMedium
                        bottomMargin: Theme.spacingSmall
                    }
                    height: 2
                    radius: 1
                    color: Theme.controlFill

                    Rectangle {
                        width: parent.width * toastCard.remaining
                        height: parent.height
                        radius: parent.radius
                        color: Theme.alpha(toastCard.toneColor, Theme.tintOutline)
                    }
                }

                IconButton {
                    id: dismissBtn
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingSmall
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingMedium
                    iconName: "close"
                    size: Theme.controlHeightSmall
                    iconSize: Theme.iconSizeTiny
                    iconColor: Theme.overlay
                    hoverColor: Theme.alpha(Theme.error, Theme.tintStrong)
                    tooltipText: "Dismiss notification"
                    onClicked: NotificationService.dismissPopup(toastCard.modelData.popupId)
                }
            }
        }
    }
}
