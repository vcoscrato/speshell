pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.services
import qs.theme
import "../components/Format.js" as Format

// A new timer, set in the bar, and the installed capture and input tools. A click on a
// tool closes the dropdown and runs it: dictation starts listening and types into the
// focused window, the others take an area the user drags out, or the whole screen from
// the row's screen button. A running dictation or recording shows in its row, and
// another click finishes it.
Card {
    id: root

    property bool presented: false

    title: "Tools"
    iconName: "tools"
    property double now: Date.now()

    // A tool installed since shows up.
    onPresentedChanged: if (root.presented) FeatureSupport.probeCommands()

    Timer {
        interval: 1000
        repeat: true
        running: root.presented && ToolsService.recording !== null
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

    Column {
        width: parent.width
        spacing: Theme.spacingSmall

        // Sets up a timer in the bar, where it then counts down.
        ActionTile {
            width: parent.width
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

                readonly property var dictation: row.modelData.id === "dictate" ? ToolsService.dictation : null
                readonly property var recording: row.modelData.id === "record" ? ToolsService.recording : null

                width: parent.width
                iconName: row.recording !== null ? "record-stop" : (row.busy ? "loader" : row.modelData.iconName)
                busy: row.dictation !== null && !ToolsService.listening
                tone: row.recording !== null ? "error" : "accent"
                active: row.recording !== null || row.dictation !== null
                label: row.recording !== null ? "Recording · " + Format.clock((root.now - row.recording.startedAt) / 1000)
                    : (row.dictation !== null ? row.dictation.detail : row.modelData.label)
                detail: row.recording !== null ? "Click to stop and save"
                    : (ToolsService.listening && row.dictation !== null ? "Click to type it out"
                    : (row.dictation !== null ? "Typing into the focused window next" : row.modelData.detail))
                secondaryIcon: row.dictation !== null ? "close"
                    : (row.modelData.screenMode && row.recording === null ? "display" : "")
                secondaryText: row.dictation !== null ? "Discard" : "Whole screen"
                onActivated: ToolsService.run(row.modelData.id, "", true)
                onSecondaryActivated: ToolsService.run(row.modelData.id, row.dictation !== null ? "cancel" : "screen", true)
            }
        }
    }
}
