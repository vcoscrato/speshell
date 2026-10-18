pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.services
import qs.theme

// The speaker (`output`) or the microphone: mute, volume, and the device to use.
Card {
    id: root

    property bool presented: false
    property bool output: true
    readonly property string kind: root.output ? "output" : "input"
    readonly property var device: root.output ? AudioService.defaultSink : AudioService.defaultSource
    readonly property bool muted: root.output ? AudioService.outputMuted : AudioService.inputMuted
    readonly property bool hasVolume: root.output ? AudioService.hasOutputVolume : AudioService.hasInputVolume
    readonly property int volumePercent: root.output
        ? AudioService.outputVolumePercent
        : AudioService.inputVolumePercent

    title: root.output ? "Speaker" : "Microphone"
    iconName: root.output ? "audio-output" : "audio-input"

    function setVolume(percent) {
        if (root.output)
            AudioService.setOutputVolumePercent(Math.round(percent));
        else
            AudioService.setInputVolumePercent(Math.round(percent));
    }

    function setDevice(node) {
        if (root.output)
            AudioService.setDefaultSink(node);
        else
            AudioService.setDefaultSource(node);
    }

    Row {
        width: parent.width
        spacing: Theme.spacingSmall

        IconButton {
            id: muteButton
            iconName: root.output
                ? (root.muted ? "audio-output-muted" : "audio-output")
                : (root.muted ? "audio-input-muted" : "audio-input")
            anchors.verticalCenter: parent.verticalCenter
            tooltipText: (root.muted ? "Unmute " : "Mute ") + root.kind
            onClicked: {
                if (root.output)
                    AudioService.toggleOutputMute();
                else
                    AudioService.toggleInputMute();
            }
        }

        StyledSlider {
            width: parent.width - muteButton.width - volumeText.width - parent.spacing * 2
            anchors.verticalCenter: parent.verticalCenter
            value: root.hasVolume ? root.volumePercent : 0
            enabled: root.device && root.hasVolume
            stepSize: AudioService.scrollStep
            onMoved: root.setVolume(value)
            onWheelAdjusted: function(nextValue) { root.setVolume(nextValue); }
        }

        Text {
            id: volumeText
            text: !root.device ? "—" : (root.hasVolume ? root.volumePercent + "%" : "…")
            font.pixelSize: Theme.fontSizeSmall
            font.family: Theme.fontFamily
            color: Theme.subtext
            width: 40
            horizontalAlignment: Text.AlignRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingTiny

        Repeater {
            model: root.presented ? AudioService.devices(root.output) : []

            delegate: Rectangle {
                id: devDelegate
                required property var modelData
                readonly property bool selected: root.device === devDelegate.modelData.node
                width: parent.width
                height: Theme.controlHeight
                radius: Theme.borderRadiusSmall
                color: devDelegate.selected
                    ? Theme.selectedFill
                    : (devMouse.containsMouse ? Theme.controlFill : "transparent")
                border.width: Theme.borderWidth
                border.color: devDelegate.selected ? Theme.selectedBorder : "transparent"

                Accessible.role: Accessible.Button
                Accessible.name: "Use " + devDelegate.modelData.label + " for audio " + root.kind
                Accessible.onPressAction: root.setDevice(devDelegate.modelData.node)
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingSmall
                    spacing: Theme.spacingSmall

                    Rectangle {
                        id: devDot
                        width: 14; height: 14; radius: 7
                        anchors.verticalCenter: parent.verticalCenter
                        border.width: 2
                        border.color: Theme.accent
                        color: devDelegate.selected ? Theme.accent : "transparent"
                    }

                    Text {
                        text: devDelegate.modelData.label
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontFamily
                        font.weight: devDelegate.selected ? Font.DemiBold : Font.Normal
                        color: Theme.text
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // A renamed device shows its hardware name on hover.
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width * 0.5)
                    visible: devDelegate.modelData.label !== devDelegate.modelData.rawLabel
                    opacity: devMouse.containsMouse ? 1 : 0
                    text: devDelegate.modelData.rawLabel
                    font.pixelSize: Theme.fontSizeCaption
                    font.family: Theme.fontFamily
                    color: Theme.overlay
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: devMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        if (!devDelegate.selected)
                            EffectsService.picked(devDot, devMouse);
                        root.setDevice(devDelegate.modelData.node);
                    }
                }
            }
        }
    }
}
