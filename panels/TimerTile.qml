pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.services
import qs.theme
import "../services/TimerProvider.js" as TimerProvider

// The timer in the Tools panel. Idle, it starts from a preset or a typed length;
// running, it shows the time left and when it ends, and adds time, pauses, or stops.
Rectangle {
    id: root

    readonly property bool running: TimerService.running
    readonly property int typedSeconds: TimerProvider.parseDuration(lengthField.text)

    function startTyped() {
        if (TimerService.start(root.typedSeconds)) {
            lengthField.text = "";
            lengthField.focus = false;
        }
    }

    implicitHeight: body.implicitHeight + Theme.spacingSmall * 2
    radius: Theme.borderRadiusSmall
    color: root.running ? Theme.alpha(Theme.accent, Theme.tintSubtle) : Theme.controlFill
    border.width: Theme.borderWidth
    border.color: root.running ? Theme.alpha(Theme.accent, Theme.tintOutline) : "transparent"

    Behavior on color {
        ColorAnimation { duration: Theme.animDurationFast }
    }

    Rectangle {
        id: disc
        x: Theme.spacingSmall
        y: Theme.spacingSmall
        width: Theme.controlHeight
        height: width
        radius: width / 2
        color: Theme.alpha(root.running ? Theme.accent : Theme.overlay, root.running ? Theme.tintStrong : Theme.tintSubtle)

        AppIcon {
            anchors.centerIn: parent
            name: "timer"
            size: Theme.iconSizeMedium
            iconColor: root.running ? Theme.accent : Theme.subtextBright
        }
    }

    Column {
        id: body
        anchors.left: disc.right
        anchors.leftMargin: Theme.spacingSmall
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingSmall
        y: Theme.spacingSmall
        spacing: Theme.spacingSmall

        // The title, as tall as the disc beside it.
        Column {
            width: parent.width
            height: disc.height
            spacing: Theme.spacingMicro

            Text {
                width: parent.width
                text: root.running ? TimerProvider.formatClock(TimerService.remainingSeconds) : "Timer"
                color: root.running ? Theme.accent : Theme.text
                font.pixelSize: Theme.fontSizeNormal
                font.family: Theme.fontFamily
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: !root.running ? "Counts down, then lets you know"
                    : TimerService.paused ? "Paused"
                    : "Ends at " + Qt.formatTime(new Date(TimerService.endsAtMs), "HH:mm")
                color: root.running ? Theme.accent : Theme.subtext
                font.pixelSize: Theme.fontSizeCaption
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }
        }

        // The time left of the whole.
        Rectangle {
            visible: root.running
            width: parent.width
            height: 3
            radius: height / 2
            color: Theme.controlFill

            Rectangle {
                width: parent.width * (TimerService.totalSeconds > 0
                    ? TimerService.remainingSeconds / TimerService.totalSeconds : 0)
                height: parent.height
                radius: height / 2
                color: Theme.accent

                Behavior on width {
                    NumberAnimation { duration: Theme.animDurationSlow; easing.type: Theme.animEasing }
                }
            }
        }

        Item {
            width: parent.width
            height: Theme.controlHeightSmall

            Row {
                id: lengths
                spacing: Theme.spacingTiny

                Repeater {
                    model: root.running ? [1, 5, 10] : TimerProvider.presets

                    delegate: ActionButton {
                        required property int modelData

                        text: (root.running ? "+" : "") + modelData + "m"
                        compact: true
                        tooltipText: (root.running ? "Add " : "Start ") + modelData + " minutes"
                        onClicked: root.running ? TimerService.add(modelData * 60) : TimerService.start(modelData * 60)
                    }
                }
            }

            // Idle: any other length.
            Rectangle {
                visible: !root.running
                anchors.left: lengths.right
                anchors.leftMargin: Theme.spacingTiny
                anchors.right: parent.right
                height: parent.height
                radius: Theme.borderRadiusSmall
                color: Theme.controlFill
                border.width: Theme.borderWidth
                border.color: lengthField.activeFocus ? Theme.accent : Theme.controlBorder

                TextInput {
                    id: lengthField
                    anchors.left: parent.left
                    anchors.right: startButton.left
                    anchors.leftMargin: Theme.spacingSmall
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.onAccent
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    clip: true
                    Accessible.name: "Timer length"
                    onAccepted: root.startTyped()
                    Keys.onEscapePressed: {
                        lengthField.text = "";
                        lengthField.focus = false;
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: lengthField.text === "" && !lengthField.activeFocus
                        text: "1h30, 90s…"
                        color: Theme.overlay
                        font: lengthField.font
                    }
                }

                IconButton {
                    id: startButton
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    size: parent.height
                    iconName: "media-play"
                    iconSize: Theme.iconSizeSmall
                    iconColor: root.typedSeconds > 0 ? Theme.accent : Theme.overlay
                    enabled: root.typedSeconds > 0
                    tooltipText: root.typedSeconds > 0 ? "Start " + TimerProvider.formatLength(root.typedSeconds) : "Type a length"
                    onClicked: root.startTyped()
                }
            }

            // Running: pause or resume, and stop.
            Row {
                visible: root.running
                anchors.right: parent.right
                spacing: Theme.spacingTiny

                ActionButton {
                    text: TimerService.paused ? "Resume" : "Pause"
                    iconName: TimerService.paused ? "media-play" : "media-pause"
                    compact: true
                    onClicked: TimerService.paused ? TimerService.resume() : TimerService.pause()
                }

                ActionButton {
                    text: "Stop"
                    iconName: "close"
                    kind: "danger"
                    compact: true
                    onClicked: TimerService.stop()
                }
            }
        }
    }
}
