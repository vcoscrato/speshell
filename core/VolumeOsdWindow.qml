pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Wayland
import qs.components
import qs.services
import qs.theme

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
    implicitHeight: 86

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
            radius: Theme.spacingMedium
            roundTopLeft: true
            roundTopRight: true
        }

        Row {
            anchors {
                fill: parent
                leftMargin: Theme.spacingLarge
                rightMargin: Theme.spacingLarge
                topMargin: Theme.spacingMedium
                bottomMargin: Theme.spacingMedium
            }
            spacing: Theme.spacingMedium

            Rectangle {
                width: 46
                height: 46
                radius: Theme.borderRadiusSmall
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.alpha(root.indicatorColor, Theme.tintSubtle)

                AppIcon {
                    anchors.centerIn: parent
                    name: root.indicatorIcon
                    size: Theme.iconSizeLarge
                    iconColor: root.indicatorColor
                }
            }

            Column {
                width: parent.width - 46 - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingSmall

                Row {
                    width: parent.width

                    Text {
                        text: root.displayedMuted ? "OUTPUT MUTED" : "OUTPUT VOLUME"
                        font.pixelSize: Theme.fontSizeCaption
                        font.family: Theme.fontFamily
                        font.bold: true
                        font.letterSpacing: 1.2
                        color: Theme.subtextBright
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item { width: parent.width - parent.children[0].width - volumeValue.width; height: 1 }

                    Text {
                        id: volumeValue
                        text: root.displayedVolume + "%"
                        font.pixelSize: Theme.fontSizeLarge
                        font.family: Theme.fontFamily
                        font.bold: true
                        color: root.indicatorColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 6
                    radius: 1
                    color: Theme.surface2
                    clip: true

                    Rectangle {
                        width: root.displayedMuted
                            ? 0
                            : parent.width * root.displayedVolume / 100
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
