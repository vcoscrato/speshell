pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Wayland
import qs.components
import qs.services
import qs.theme

// What OsdService shows at the bottom of the screen: a level, as with volume and
// brightness keys, or a state, as with the microphone's mute.
OsdWindow {
    id: root

    property string displayedIcon: "info"
    property string displayedTitle: ""
    property string displayedValue: ""
    // 0 to 1, or -1 without a bar.
    property real displayedLevel: -1

    readonly property color indicatorColor: Theme.accent

    card: osdCard
    implicitWidth: 316
    implicitHeight: osdContent.implicitHeight + Theme.spacingMedium * 2

    anchors {
        bottom: true
    }

    // Quickshell's type info hides the fields of PanelWindow.margins.
    // qmllint disable missing-property
    margins {
        bottom: 64
    }
    // qmllint enable missing-property

    WlrLayershell.namespace: "speshell-osd"

    Connections {
        target: OsdService

        function onRequested(iconName, title, value, level) {
            root.targetScreen = HyprlandService.focusedScreen();
            root.displayedIcon = iconName;
            root.displayedTitle = title;
            root.displayedValue = value;
            root.displayedLevel = level;
            hideTimer.restart();
            root.present();
        }
    }

    Timer {
        id: hideTimer
        interval: 1200
        repeat: false
        onTriggered: root.dismiss()
    }

    Item {
        id: osdCard
        anchors.fill: parent

        // Bottom center of the screen: rounded toward its center.
        Surface {
            anchors.fill: parent
            backdrop: true
            roundTopLeft: true
            roundTopRight: true
        }

        Row {
            id: osdContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.spacingLarge
            anchors.rightMargin: Theme.spacingLarge
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingMedium

            IconDisc {
                id: disc
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.controlHeight * 1.5
                iconName: root.displayedIcon
                lit: true
            }

            Column {
                width: parent.width - disc.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingSmall

                Item {
                    width: parent.width
                    height: valueLabel.implicitHeight

                    Label {
                        role: "section"
                        anchors.left: parent.left
                        anchors.right: valueLabel.left
                        anchors.rightMargin: Theme.spacingSmall
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.displayedTitle
                        elide: Text.ElideRight
                    }

                    Label {
                        id: valueLabel
                        role: "heading"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.displayedValue
                        color: root.indicatorColor
                        font.features: { "tnum": 1 }
                    }
                }

                // As the timer's progress bar.
                Rectangle {
                    visible: root.displayedLevel >= 0
                    width: parent.width
                    height: Theme.spacingTiny
                    radius: height / 2
                    color: Theme.surface2

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, root.displayedLevel))
                        height: parent.height
                        radius: parent.radius
                        color: root.indicatorColor

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.animDurationFast
                                easing.type: Theme.animEasing
                            }
                        }
                    }
                }
            }
        }
    }
}
