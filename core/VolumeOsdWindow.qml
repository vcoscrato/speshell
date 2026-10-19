pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Wayland
import qs.components
import qs.services
import qs.theme

// The volume shown at the bottom of the screen when it changes from outside Speshell,
// as with media keys.
OsdWindow {
    id: root

    property int displayedVolume: 0
    property bool displayedMuted: false

    readonly property color indicatorColor: Theme.accent
    readonly property string indicatorIcon: root.displayedMuted
        ? "audio-output-muted"
        : (root.displayedVolume <= 35 ? "audio-output-low" : "audio-output-high")

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

    WlrLayershell.namespace: "speshell-volume-osd"

    Connections {
        target: AudioService

        function onOutputOsdRequested(volumePercent, muted) {
            root.targetScreen = HyprlandService.focusedScreen();
            root.displayedVolume = Math.max(0, Math.min(100, Math.round(Number(volumePercent) || 0)));
            root.displayedMuted = !!muted;
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
                iconName: root.indicatorIcon
                lit: true
            }

            Column {
                width: parent.width - disc.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingSmall

                Item {
                    width: parent.width
                    height: volumeValue.implicitHeight

                    Label {
                        role: "section"
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.displayedMuted ? "Output muted" : "Output volume"
                    }

                    Label {
                        id: volumeValue
                        role: "heading"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.displayedVolume + "%"
                        color: root.indicatorColor
                        font.features: { "tnum": 1 }
                    }
                }

                // As the timer's progress bar.
                Rectangle {
                    width: parent.width
                    height: Theme.spacingTiny
                    radius: height / 2
                    color: Theme.surface2

                    Rectangle {
                        width: root.displayedMuted ? 0 : parent.width * root.displayedVolume / 100
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
