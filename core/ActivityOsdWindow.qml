pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland
import qs.components
import qs.services
import qs.theme

OsdWindow {
    id: root

    property var displayedActivities: []
    property double nowMs: Date.now()

    function syncActivities() {
        var active = ActivityService.activities;
        if (active.length > 0) {
            root.displayedActivities = active.slice();
            root.present();
        } else {
            root.dismiss();
        }
    }

    card: activityColumn
    entranceScale: 0.97
    implicitWidth: 390
    implicitHeight: activityColumn.implicitHeight

    anchors { top: true }
    // Quickshell's type info hides the fields of PanelWindow.margins.
    // qmllint disable missing-property
    margins { top: Theme.spacingLarge }
    // qmllint enable missing-property

    WlrLayershell.namespace: "speshell-activity-osd"

    Component.onCompleted: root.syncActivities()
    onHidden: root.displayedActivities = []

    Connections {
        target: ActivityService
        function onActivitiesChanged() { root.syncActivities(); }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.shown
        onTriggered: root.nowMs = Date.now()
    }

    Column {
        id: activityColumn

        width: parent.width
        spacing: Theme.spacingSmall

        Repeater {
            model: root.displayedActivities

            delegate: Item {
                id: activityCard

                required property var modelData
                readonly property color toneColor: Theme.toneColor(modelData.tone)
                readonly property string elapsed: ActivityService.elapsedText(
                    modelData.startedAt,
                    root.nowMs
                )
                readonly property bool busy: modelData.state === "busy"

                // The spinner stops wherever it is; set the icon upright again.
                onBusyChanged: if (!activityCard.busy) activityIcon.rotation = 0

                width: activityColumn.width
                implicitHeight: Math.max(70, cardContent.implicitHeight + Theme.spacingXL)
                height: implicitHeight

                // Top center of the screen: cut toward its center.
                Surface {
                    anchors.fill: parent
                    cut: Theme.spacingMedium
                    cutBottomLeft: true
                    cutBottomRight: true
                }

                Row {
                    id: cardContent

                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: Theme.spacingLarge
                        rightMargin: Theme.spacingLarge
                    }
                    spacing: Theme.spacingMedium

                    Rectangle {
                        width: 42
                        height: 42
                        radius: Theme.borderRadiusSmall
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.alpha(activityCard.toneColor, Theme.tintSubtle)

                        AppIcon {
                            id: activityIcon
                            anchors.centerIn: parent
                            name: activityCard.modelData.iconName
                            size: Theme.iconSizeLarge
                            iconColor: activityCard.toneColor

                            RotationAnimator on rotation {
                                from: 0
                                to: 360
                                duration: 900
                                loops: Animation.Infinite
                                running: activityCard.busy
                            }
                        }

                        Rectangle {
                            id: stateDot
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: -2
                            anchors.bottomMargin: -2
                            width: 10
                            height: 10
                            radius: 5
                            color: activityCard.toneColor
                            border.width: 2
                            border.color: Theme.bg

                            // A still dot in power saver.
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                running: activityCard.modelData.state === "active" && Theme.motion
                                onRunningChanged: if (!running) stateDot.opacity = 1
                                NumberAnimation { to: 0.35; duration: 650; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
                            }
                        }
                    }

                    Column {
                        width: Math.max(
                            80,
                            cardContent.width - 42 - actionRow.width - (cardContent.spacing * 2)
                        )
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingTiny

                        Text {
                            width: parent.width
                            text: activityCard.modelData.label
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            font.pixelSize: Theme.fontSizeNormal
                            font.family: Theme.fontFamily
                            font.bold: true
                            color: Theme.text
                        }

                        Text {
                            width: parent.width
                            text: (activityCard.modelData.detail !== ""
                                ? activityCard.modelData.detail + " · "
                                : "") + activityCard.elapsed
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontFamily
                            color: Theme.subtext
                        }
                    }

                    Row {
                        id: actionRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingSmall

                        Repeater {
                            model: activityCard.modelData.actions

                            delegate: ActionButton {
                                required property var modelData
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                iconName: modelData.iconName
                                kind: modelData.kind
                                onClicked: ActivityService.requestAction(
                                    activityCard.modelData.provider,
                                    activityCard.modelData.id,
                                    modelData.id
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
