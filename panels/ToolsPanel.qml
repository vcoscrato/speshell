pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.services
import qs.theme

// The timer, and the installed capture and input tools. A click on a tool closes the
// dropdown and runs it: dictation starts listening and types into the focused window,
// the others take an area the user drags out, or the whole screen from the row's
// screen button. A running dictation or recording shows in its row, and another click
// finishes it.
Card {
    id: root

    property bool presented: false

    title: "Tools"
    iconName: "tools"
    property double now: Date.now()

    onPresentedChanged: if (root.presented) ToolsService.probe()

    function formatElapsed(startedAt) {
        var seconds = Math.max(0, Math.floor((root.now - startedAt) / 1000));
        var rest = seconds % 60;
        return Math.floor(seconds / 60) + ":" + (rest < 10 ? "0" : "") + rest;
    }

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

        TimerTile {
            width: parent.width
        }

        Repeater {
            model: ToolsService.tools

            delegate: ToolRow {
                id: row

                required property var modelData

                readonly property var dictation: row.modelData.id === "dictate" ? ToolsService.dictation : null
                readonly property var recording: row.modelData.id === "record" ? ToolsService.recording : null

                width: parent.width
                iconName: row.recording !== null ? "record-stop" : (row.dictation !== null && !ToolsService.listening
                    ? "loader" : row.modelData.iconName)
                busy: row.dictation !== null && !ToolsService.listening
                tone: row.recording !== null ? "error" : "accent"
                running: row.recording !== null || row.dictation !== null
                label: row.recording !== null ? "Recording · " + root.formatElapsed(row.recording.startedAt)
                    : (row.dictation !== null ? row.dictation.detail : row.modelData.label)
                detail: row.recording !== null ? "Click to stop and save"
                    : (ToolsService.listening && row.dictation !== null ? "Click to type it out"
                    : (row.dictation !== null ? "Typing into the focused window next" : row.modelData.detail))
                secondaryIcon: row.dictation !== null ? "close"
                    : (row.modelData.screenMode && row.recording === null ? "display" : "")
                secondaryText: row.dictation !== null ? "Discard" : "Whole screen"
                onActivated: ToolsService.run(row.modelData.id, "")
                onSecondaryActivated: ToolsService.run(row.modelData.id, row.dictation !== null ? "cancel" : "screen")
            }
        }
    }

    component ToolRow: Rectangle {
        id: tile

        property string label: ""
        property string detail: ""
        property string iconName: ""
        property string tone: "accent"
        property bool running: false
        property bool busy: false
        property string secondaryIcon: ""
        property string secondaryText: ""

        readonly property color toneColor: Theme.toneColor(tile.tone)
        readonly property bool hot: tile.running || (tileMouse.containsMouse && !tile.busy)

        signal activated()
        signal secondaryActivated()

        implicitHeight: Math.max(Theme.controlHeight, tileText.implicitHeight)
            + Theme.spacingSmall * 2
        radius: Theme.borderRadiusSmall
        color: tile.running
            ? Theme.alpha(tile.toneColor, Theme.tintStrong)
            : (tile.hot ? Theme.alpha(tile.toneColor, Theme.tintSubtle) : Theme.controlFill)
        border.width: Theme.borderWidth
        border.color: tile.running
            ? Theme.alpha(tile.toneColor, Theme.tintOutlineStrong)
            : (tile.hot ? Theme.alpha(tile.toneColor, Theme.tintOutline) : "transparent")

        Behavior on color {
            ColorAnimation { duration: Theme.animDurationFast }
        }

        Accessible.role: Accessible.Button
        Accessible.name: tile.label
        Accessible.description: tile.detail
        Accessible.onPressAction: if (!tile.busy) tile.activated()

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: tile.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: if (!tile.busy) tile.activated()
        }

        Rectangle {
            id: disc
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.controlHeight
            height: width
            radius: width / 2
            color: Theme.alpha(tile.hot ? tile.toneColor : Theme.overlay,
                tile.hot ? Theme.tintStrong : Theme.tintSubtle)

            AppIcon {
                id: discIcon
                anchors.centerIn: parent
                name: tile.iconName
                size: Theme.iconSizeMedium
                iconColor: tile.hot ? tile.toneColor : Theme.subtextBright

                RotationAnimator on rotation {
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                    running: tile.busy
                    onRunningChanged: if (!running) discIcon.rotation = 0
                }
            }
        }

        Column {
            id: tileText
            anchors.left: disc.right
            anchors.leftMargin: Theme.spacingSmall
            anchors.right: secondary.visible ? secondary.left : parent.right
            anchors.rightMargin: Theme.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingMicro

            Text {
                width: parent.width
                text: tile.label
                color: Theme.text
                font.pixelSize: Theme.fontSizeNormal
                font.family: Theme.fontFamily
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: tile.detail
                color: tile.running ? tile.toneColor : Theme.subtext
                font.pixelSize: Theme.fontSizeCaption
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }
        }

        IconButton {
            id: secondary
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingSmall
            anchors.verticalCenter: parent.verticalCenter
            visible: tile.secondaryIcon !== ""
            iconName: tile.secondaryIcon
            iconSize: Theme.iconSizeSmall
            iconColor: secondary.containsMouse ? tile.toneColor : Theme.subtextBright
            hoverColor: Theme.alpha(tile.toneColor, Theme.tintStrong)
            tooltipText: tile.secondaryText
            onClicked: tile.secondaryActivated()
        }
    }
}
