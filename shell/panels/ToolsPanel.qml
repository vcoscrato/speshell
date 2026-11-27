pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.services
import "../components/Format.js" as Format

// A new timer, set in the bar, and the installed capture and input tools. A click on a
// tool closes the dropdown and runs it: dictation listens, in its card, the others take
// an area the user drags out, or the whole screen from the row's screen button. A running
// dictation or recording shows in its row, and another click stops it, or types the
// dictation into the focused window.
Card {
    id: root

    panel: "tools"
    property double now: Date.now()

    // A tool installed since shows up.
    Component.onCompleted: FeatureSupport.probeCommands()

    Timer {
        interval: 1000
        repeat: true
        running: ToolsService.recording !== null
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    // Sets up a timer in the bar, where it then counts down.
    ActionTile {
        width: parent.width
        flat: true
        iconName: "timer"
        label: "Timer"
        detail: "Count down in the bar"
        onActivated: {
            TimerService.create();
            PanelService.open("timer");
        }
    }

    Repeater {
        model: ToolsService.tools

        delegate: ActionTile {
            id: row

            required property var modelData

            readonly property var dictation: row.modelData.id === "dictate" ? DictationService.activity : null
            readonly property var recording: row.modelData.id === "record" ? ToolsService.recording : null

            width: parent.width
            flat: true
            iconName: row.recording !== null ? "record-stop"
                : (row.dictation !== null ? row.dictation.iconName : row.modelData.iconName)
            busy: row.dictation !== null && row.dictation.state === "busy"
            tone: row.recording !== null ? "error" : "accent"
            active: row.recording !== null || row.dictation !== null
            label: row.recording !== null ? "Recording · " + Format.clock((root.now - row.recording.startedAt) / 1000)
                : (row.dictation !== null ? row.dictation.detail : row.modelData.label)
            detail: row.recording !== null ? "Click to stop and save"
                : DictationService.phase === "listening" && row.dictation !== null ? "Click to stop"
                : DictationService.phase === "ready" && row.dictation !== null ? "Click to type it out"
                : (row.dictation !== null ? "" : row.modelData.detail)
            secondaryIcon: row.dictation !== null ? "close"
                : (row.modelData.screenMode && row.recording === null ? "display" : "")
            secondaryText: row.dictation !== null ? "Discard" : "Whole screen"
            onActivated: ToolsService.run(row.modelData.id, "", true)
            onSecondaryActivated: ToolsService.run(row.modelData.id, row.dictation !== null ? "cancel" : "screen", true)
        }
    }
}
