pragma ComponentBehavior: Bound
// Quickshell's type info marks PanelWindow uncreatable, though QML creates it.
// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import qs.services
import qs.theme
import qs.components

PanelWindow {
    id: root

    property var targetScreen: HyprlandService.focusedScreen()

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
        top: true
        right: true
    }

    // Quickshell's type info hides the fields of PanelWindow.margins.
    // qmllint disable missing-property
    margins {
        top: Theme.spacingLarge
        right: Theme.spacingLarge
    }
    // qmllint enable missing-property

    color: "transparent"
    implicitWidth: 350
    implicitHeight: toastColumn.height
    visible: NotificationService.activePopups.length > 0

    Column {
        id: toastColumn
        width: parent.width
        spacing: Theme.spacingMedium

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

                width: parent.width
                height: toastContent.height + (Theme.spacingMedium * 2)

                // Top right of the screen: rounded toward its center, accent edge on the left.
                Surface {
                    anchors.fill: parent
                    radius: Theme.spacingMedium
                    roundBottomLeft: true
                    edge: "left"
                    edgeColor: toastCard.toneColor
                    fillColor: toastMouse.containsMouse ? Theme.card : Theme.bg

                    Behavior on fillColor {
                        ColorAnimation { duration: Theme.animDuration }
                    }
                }

                scale: 0.95
                opacity: 0
                Component.onCompleted: entranceAnim.start()

                ParallelAnimation {
                    id: entranceAnim
                    NumberAnimation { target: toastCard; property: "scale"; to: 1.0; duration: Theme.animDuration; easing.type: Easing.OutBack }
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
                        leftMargin: Theme.spacingLarge
                    }
                    spacing: Theme.spacingSmall

                    Row {
                        spacing: Theme.spacingSmall

                        Image {
                            width: 16
                            height: 16
                            anchors.verticalCenter: parent.verticalCenter
                            visible: toastCard.notificationIcon !== ""
                            source: toastCard.notificationIcon
                            sourceSize: Qt.size(32, 32)
                            fillMode: Image.PreserveAspectFit
                        }

                        SpeshellMark {
                            size: 16
                            anchors.verticalCenter: parent.verticalCenter
                            visible: toastCard.internal && toastCard.notificationIcon === ""
                        }

                        Text {
                            text: toastCard.modelData.appName || "App"
                            textFormat: Text.PlainText
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: Theme.fontSizeCaption
                            font.family: Theme.fontFamily
                            font.bold: true
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 0.8
                            color: toastCard.toneColor
                        }
                    }

                    Text {
                        text: (toastCard.live ? toastCard.live.summary : toastCard.modelData.summary) || ""
                        textFormat: Text.PlainText
                        font.pixelSize: Theme.fontSizeNormal
                        font.family: Theme.fontFamily
                        font.bold: true
                        color: Theme.text
                        width: parent.width
                        elide: Text.ElideRight
                        visible: text !== ""
                    }

                    Text {
                        text: (toastCard.live ? toastCard.live.body : toastCard.modelData.body) || ""
                        textFormat: Text.PlainText
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
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

                IconButton {
                    id: dismissBtn
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingSmall
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingSmall
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
