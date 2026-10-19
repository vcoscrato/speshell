pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.services
import qs.theme
import "../services/TimerProvider.js" as TimerProvider
import "../components/Format.js" as Format

// A timer, opened from its chip in the bar. New, it takes a name and starts from a
// preset or a typed length. Running, it shows its name, the time left and when it ends
// over how much has gone, and buttons to add time, pause, and stop it. A new timer the
// panel leaves unset goes with it.
Card {
    id: root

    property var timer: null
    // The timer last shown, to throw away if it was left unset.
    property var held: null
    readonly property bool isSet: root.timer !== null && root.timer.isSet
    readonly property bool paused: root.isSet && root.timer.paused
    readonly property var typed: TimerProvider.parseTimer(lengthField.text)

    // Set, stopped, or gone; the dropdown closes.
    signal done()

    function discard(timer) {
        if (timer && !timer.isSet && TimerService.timers.indexOf(timer) >= 0)
            TimerService.stop(timer);
    }

    // Starts the new timer for `seconds`, under the name typed, or else `name`.
    function begin(seconds, name) {
        TimerService.rename(root.timer, nameField.text.trim() || name);
        if (TimerService.set(root.timer, seconds))
            root.done();
    }

    function beginTyped() {
        if (root.typed.seconds > 0)
            root.begin(root.typed.seconds, root.typed.name);
    }

    onTimerChanged: {
        root.discard(root.held);
        root.held = root.timer;
        nameField.text = "";
        lengthField.text = "";
        nameInput.text = root.timer ? root.timer.name : "";
        if (root.timer !== null && !root.timer.isSet)
            Qt.callLater(() => nameField.focusInput());
    }
    Component.onDestruction: root.discard(root.held)

    Connections {
        target: TimerService

        function onChanged() {
            if (root.timer !== null && TimerService.timers.indexOf(root.timer) < 0)
                root.done();
        }
    }

    implicitWidth: Math.round(Theme.panelWidth * 0.8)
    title: root.isSet ? "Timer" : "New timer"
    iconName: "timer"

    // ── New: a name, then a preset or a typed length ──
    Field {
        id: nameField
        visible: !root.isSet
        placeholder: "Name it, like Pasta"
        onAccepted: root.typed.seconds > 0 ? root.beginTyped() : lengthField.focusInput()
        onCancelled: root.done()
    }

    Row {
        visible: !root.isSet
        width: parent.width
        spacing: Theme.spacingTiny

        Repeater {
            model: TimerProvider.presets

            delegate: ActionButton {
                required property int modelData

                width: (parent.width - Theme.spacingTiny * (TimerProvider.presets.length - 1)) / TimerProvider.presets.length
                text: modelData + " min"
                onClicked: root.begin(modelData * 60, "")
            }
        }
    }

    Row {
        visible: !root.isSet
        width: parent.width
        spacing: Theme.spacingTiny

        Field {
            id: lengthField
            width: parent.width - startButton.width - parent.spacing
            placeholder: "Or a length, like 1h30"
            onAccepted: root.beginTyped()
            onCancelled: root.done()
        }

        ActionButton {
            id: startButton
            text: "Start"
            iconName: "media-play"
            enabled: root.typed.seconds > 0
            tooltipText: root.typed.seconds > 0 ? Format.duration(root.typed.seconds) : "Type a length"
            onClicked: root.beginTyped()
        }
    }

    // ── Running: its name, the time left and when it ends, and how much has gone ──
    TextInput {
        id: nameInput
        visible: root.isSet
        width: parent.width
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.onAccent
        font.pixelSize: Theme.fontSizeLarge
        font.family: Theme.fontFamily
        font.weight: Font.DemiBold
        clip: true
        Accessible.name: "Timer name"
        onTextEdited: TimerService.rename(root.timer, nameInput.text)
        onAccepted: nameInput.focus = false

        Text {
            visible: nameInput.text === "" && !nameInput.activeFocus
            text: "Add a name"
            color: Theme.overlay
            font: nameInput.font
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.IBeamCursor
        }
    }

    Item {
        visible: root.isSet
        width: parent.width
        height: countdown.implicitHeight

        Label {
            id: countdown
            role: "display"
            text: root.isSet ? Format.clock(root.timer.remainingSeconds) : ""
            color: root.paused ? Theme.subtext : Theme.accent
            font.features: { "tnum": 1 }
        }

        Label {
            anchors.right: parent.right
            anchors.baseline: countdown.baseline
            text: !root.isSet ? ""
                : root.paused ? "Paused"
                : "Ends at " + Format.time(new Date(root.timer.endsAtMs))
            color: Theme.subtext
        }

        // Scrolling changes it by a minute.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                if (wheel.angleDelta.y)
                    TimerService.add(root.timer, wheel.angleDelta.y > 0 ? 60 : -60);
            }
        }
    }

    Rectangle {
        visible: root.isSet
        width: parent.width
        height: Theme.spacingTiny
        radius: height / 2
        color: Theme.surface2

        Rectangle {
            width: root.isSet ? parent.width * root.timer.remainingSeconds / root.timer.totalSeconds : 0
            height: parent.height
            radius: parent.radius
            color: root.paused ? Theme.overlay : Theme.accent
        }
    }

    // ── Running: more time, pause or resume, and stop ──
    Row {
        visible: root.isSet
        width: parent.width
        spacing: Theme.spacingTiny

        Repeater {
            model: [1, 5, 10]

            delegate: ActionButton {
                required property int modelData

                width: (parent.width - Theme.spacingTiny * 2) / 3
                text: "+" + modelData + " min"
                onClicked: TimerService.add(root.timer, modelData * 60)
            }
        }
    }

    Row {
        visible: root.isSet
        width: parent.width
        spacing: Theme.spacingTiny

        ActionButton {
            width: (parent.width - parent.spacing) / 2
            text: root.paused ? "Resume" : "Pause"
            iconName: root.paused ? "media-play" : "media-pause"
            kind: root.paused ? "primary" : "secondary"
            onClicked: TimerService.toggle(root.timer)
        }

        ActionButton {
            width: (parent.width - parent.spacing) / 2
            text: "Stop"
            iconName: "record-stop"
            kind: "danger"
            onClicked: TimerService.stop(root.timer)
        }
    }
}
