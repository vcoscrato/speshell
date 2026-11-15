pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.services

// The displays: each one's mode, and on and off, their layout and position, applied
// on request and kept or reverted.
Card {
    id: root
    panel: "display"
    visible: FeatureSupport.supportsDisplayControl

    property bool presented: false
    // With one display there is nothing to arrange, so the map and picker step aside.
    readonly property bool multiple: DisplayService.draftMonitors.length > 1
    readonly property bool busy: DisplayService.busy
    readonly property var selectedMonitor: DisplayService.selectedMonitor
    readonly property bool selectedEnabled: root.selectedMonitor !== null && !root.selectedMonitor.disabled
    readonly property var selectedModeOptions: root.selectedEnabled ? root.selectedMonitor.modes : []
    readonly property var selectedAnchor: root.selectedEnabled ? DisplayService.anchorFor(root.selectedMonitor) : null
    readonly property bool canPositionSelected: root.selectedAnchor !== null && DisplayService.draftLayoutMode === "extend"
    readonly property bool canControlSelectedBrightness: root.selectedEnabled
        && BrightnessService.available
        && root.isBrightnessDisplay(root.selectedMonitor)

    Component.onCompleted: {
        if (root.presented) {
            DisplayService.refresh();
            root.requestBrightnessRefresh();
        }
    }

    onPresentedChanged: {
        if (root.presented) {
            DisplayService.refresh();
            root.requestBrightnessRefresh();
        }
    }

    onSelectedMonitorChanged: root.requestBrightnessRefresh()
    onCanControlSelectedBrightnessChanged: root.requestBrightnessRefresh()

    function isBrightnessDisplay(monitor) {
        return monitor !== null && (DisplayService.isInternal(monitor) || DisplayService.draftActiveMonitors.length <= 1);
    }

    function layoutLabel(mode) {
        return { mirror: "Mirror", extend: "Extend" }[mode] || "Single";
    }

    // What needs attention; "" when the displays are just as reported.
    function noticeText() {
        if (DisplayService.errorText !== "")
            return DisplayService.errorText;
        const phases = {
            reverting: "Restoring the previous display layout.",
            interrupted: "Restoring the previous display layout.",
            confirming: "Waiting for display confirmation.",
            applying: "Applying display changes.",
            layout: "Applying display changes."
        };
        if (phases[DisplayService.phase])
            return phases[DisplayService.phase];
        if (DisplayService.loading)
            return "Reading display state.";
        if (DisplayService.hasPending)
            return DisplayService.pendingSummary;
        if (DisplayService.monitors.length === 0)
            return "No displays reported by Hyprland.";
        return "";
    }

    function statusText() {
        return root.noticeText() || (DisplayService.draftActiveMonitors.length + " active / "
            + DisplayService.draftMonitors.length + " detected");
    }

    function positionLabel() {
        if (!root.canPositionSelected)
            return "Auto";
        const anchor = root.selectedAnchor;
        const dx = root.selectedMonitor.x - anchor.x;
        const dy = root.selectedMonitor.y - anchor.y;
        if (Math.abs(dx) >= Math.abs(dy))
            return (dx < 0 ? "Left of " : "Right of ") + anchor.name;
        return (dy < 0 ? "Above " : "Below ") + anchor.name;
    }

    // Where `monitor` shows on the map, a `width` by `height` picture of the draft:
    // side by side when mirrored, else as they are placed.
    function mapRect(monitor, width, height) {
        const padding = 10;
        const availableWidth = Math.max(1, width - padding * 2);
        const availableHeight = Math.max(1, height - padding * 2);
        const active = DisplayService.draftActiveMonitors;
        const monitorWidth = DisplayService.logicalWidth(monitor);
        const monitorHeight = DisplayService.logicalHeight(monitor);
        if (DisplayService.draftLayoutMode === "mirror") {
            const index = Math.max(0, active.findIndex(other => other.name === monitor.name));
            const slotWidth = availableWidth / active.length;
            const scale = Math.min(Math.max(1, slotWidth - 6) / monitorWidth, availableHeight / monitorHeight);
            const tileWidth = Math.max(34, monitorWidth * scale);
            const tileHeight = Math.max(24, monitorHeight * scale);
            return {
                x: padding + index * slotWidth + Math.max(0, (slotWidth - tileWidth) / 2),
                y: padding + Math.max(0, (availableHeight - tileHeight) / 2),
                width: tileWidth,
                height: tileHeight
            };
        }
        const bounds = DisplayService.boundsOf(active);
        const scale = Math.min(availableWidth / bounds.width, availableHeight / bounds.height);
        return {
            x: padding + (monitor.x - bounds.minX) * scale,
            y: padding + (monitor.y - bounds.minY) * scale,
            width: Math.max(34, monitorWidth * scale),
            height: Math.max(24, monitorHeight * scale)
        };
    }

    function requestBrightnessRefresh() {
        if (root.presented && root.canControlSelectedBrightness)
            BrightnessService.refresh();
    }

    headerActions: Row {
        spacing: Theme.spacingSmall

        ActionButton {
            visible: DisplayService.hasPending
            text: "Revert"
            iconName: "back"
            compact: true
            enabled: DisplayService.phase === "idle"
            onClicked: DisplayService.resetDraft()
        }

        ActionButton {
            visible: DisplayService.hasPending
            text: "Apply"
            iconName: "check"
            kind: "primary"
            compact: true
            enabled: DisplayService.hasPending && !root.busy
            onClicked: DisplayService.applyDraft()
        }

        ActionButton {
            visible: DisplayService.canRetryRevert
            text: "Retry revert"
            iconName: "back"
            kind: "danger"
            compact: true
            onClicked: DisplayService.revertDisplayChanges()
        }

        HeaderButton {
            id: nightLightButton
            visible: NightLightService.available
            iconName: "night-light"
            iconColor: NightLightService.errorText !== "" ? Theme.error
                : NightLightService.active ? Theme.accent
                : nightLightButton.containsMouse ? Theme.text : Theme.subtext
            tooltipText: NightLightService.errorText !== "" ? "Night light failed: " + NightLightService.errorText
                : NightLightService.enabled ? "Turn the night light off" : "Turn the night light on"
            onClicked: NightLightService.setEnabled(!NightLightService.enabled)
        }

        HeaderButton {
            iconName: "refresh"
            busy: root.busy
            enabled: !root.busy
            tooltipText: root.busy ? "Refreshing displays" : "Refresh displays"
            onClicked: DisplayService.refresh()
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingMedium

        Row {
            id: statusRow
            width: parent.width
            spacing: Theme.spacingSmall
            visible: root.multiple || root.noticeText() !== ""

            Pill {
                id: layoutBadge
                visible: root.multiple
                anchors.verticalCenter: parent.verticalCenter
                text: root.layoutLabel(DisplayService.draftLayoutMode)
            }

            Label {
                width: Math.max(0, statusRow.width
                    - (layoutBadge.visible ? layoutBadge.width + statusRow.spacing : 0))
                text: root.multiple ? root.statusText() : root.noticeText()
                color: DisplayService.errorText !== ""
                    ? Theme.error
                    : (DisplayService.hasPending ? Theme.warning : Theme.subtext)
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Notice {
            id: changeNotice

            readonly property bool confirming: DisplayService.phase === "confirming"

            visible: confirming || DisplayService.phase === "reverting" || DisplayService.phase === "interrupted"
            heading: confirming ? "Keep these display settings?" : "Restoring previous display settings…"
            detail: confirming
                ? "Changes revert automatically in " + DisplayService.confirmationSecondsRemaining + " seconds."
                : ""

            Row {
                width: parent.width
                spacing: Theme.spacingSmall
                visible: changeNotice.confirming

                ActionButton {
                    width: (parent.width - parent.spacing) / 2
                    text: "Revert"
                    iconName: "back"
                    onClicked: DisplayService.revertDisplayChanges()
                }

                ActionButton {
                    width: (parent.width - parent.spacing) / 2
                    text: "Keep changes"
                    iconName: "check"
                    kind: "primary"
                    onClicked: DisplayService.keepDisplayChanges()
                }
            }
        }

        Rectangle {
            id: displayMap
            width: parent.width
            height: 148
            visible: root.multiple
            radius: Theme.borderRadius
            color: Theme.controlFill
            border.width: Theme.borderWidth
            border.color: Theme.controlBorder
            clip: true

            Label {
                anchors.centerIn: parent
                text: "No active displays"
                visible: DisplayService.draftActiveMonitors.length === 0
                color: Theme.overlay
            }

            Repeater {
                model: DisplayService.draftActiveMonitors

                delegate: Rectangle {
                    id: displayTile

                    required property var modelData
                    readonly property var rect: root.mapRect(displayTile.modelData, displayMap.width, displayMap.height)
                    readonly property bool selected: displayTile.modelData.name === DisplayService.selectedName

                    x: rect.x
                    y: rect.y
                    width: Math.min(Math.max(34, rect.width), displayMap.width - 20)
                    height: Math.min(Math.max(24, rect.height), displayMap.height - 20)
                    radius: Theme.borderRadius
                    z: selected ? 2 : 1
                    color: selected
                        ? Theme.alpha(Theme.accent, Theme.tintStrong)
                        : Theme.alpha(Theme.surface2, 0.72)
                    border.width: Theme.borderWidth
                    border.color: selected
                        ? Theme.accent
                        : Theme.alpha(Theme.overlay, Theme.tintOutline)

                    Accessible.role: Accessible.Button
                    Accessible.name: "Select " + displayTile.modelData.name
                    Accessible.onPressAction: DisplayService.setSelected(displayTile.modelData.name)

                    Label {
                        role: "caption"
                        anchors.centerIn: parent
                        width: Math.max(0, parent.width - Theme.spacingSmall)
                        text: displayTile.modelData.name
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        font.weight: Font.Bold
                        color: Theme.text
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: DisplayService.setSelected(displayTile.modelData.name)
                    }

                    Behavior on x { NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing } }
                    Behavior on y { NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing } }
                    Behavior on width { NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing } }
                    Behavior on height { NumberAnimation { duration: Theme.animDuration; easing.type: Theme.animEasing } }
                }
            }
        }

        Flow {
            id: displayPicker
            width: parent.width
            spacing: Theme.spacingSmall
            visible: root.multiple

            Repeater {
                model: DisplayService.draftMonitors

                delegate: Rectangle {
                    id: displayPill

                    required property var modelData
                    readonly property bool selected: displayPill.modelData.name === DisplayService.selectedName
                    readonly property color pillColor: displayPill.modelData.disabled
                        ? Theme.overlay
                        : Theme.accent

                    width: Math.min(displayPicker.width, Math.max(82, pillText.implicitWidth + pillState.implicitWidth + 26))
                    height: Theme.controlHeightSmall
                    radius: Theme.borderRadius
                    opacity: root.busy ? Theme.disabledOpacity : 1.0
                    color: Theme.alpha(pillColor,
                        selected ? Theme.tintStrong : Theme.tintSubtle)
                    border.width: Theme.borderWidth
                    border.color: Theme.alpha(pillColor,
                        selected ? Theme.tintOutlineStrong : Theme.tintOutline)

                    Accessible.role: Accessible.Button
                    Accessible.name: "Select " + displayPill.modelData.name
                    Accessible.description: displayPill.modelData.disabled ? "Display off" : "Display on"
                    Accessible.onPressAction: DisplayService.setSelected(displayPill.modelData.name)

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingTiny

                        Label {
                            id: pillText
                            role: "caption"
                            width: Math.min(138, implicitWidth)
                            text: displayPill.modelData.name
                            font.weight: Font.Bold
                            color: displayPill.modelData.disabled ? Theme.subtext : Theme.text
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Label {
                            id: pillState
                            text: displayPill.modelData.disabled ? "Off" : "On"
                            font.pixelSize: Theme.fontSizeMicro
                            color: displayPill.pillColor
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !root.busy
                        hoverEnabled: true
                        cursorShape: root.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: DisplayService.setSelected(displayPill.modelData.name)
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            visible: root.selectedMonitor !== null
            implicitHeight: editorColumn.implicitHeight + Theme.spacingMedium * 2
            radius: Theme.borderRadius
            color: Theme.controlFill
            border.width: Theme.borderWidth
            border.color: Theme.controlBorder

            Column {
                id: editorColumn
                x: Theme.spacingMedium
                y: Theme.spacingMedium
                width: parent.width - Theme.spacingMedium * 2
                spacing: Theme.spacingSmall

                Row {
                    width: parent.width
                    spacing: Theme.spacingSmall

                    AppIcon {
                        name: "display"
                        size: Theme.iconSizeMedium
                        iconColor: root.selectedEnabled ? Theme.accent : Theme.subtext
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: Math.max(40, parent.width - Theme.iconSizeMedium - Theme.spacingSmall
                            - (outputSwitch.visible ? outputSwitch.width + Theme.spacingSmall : 0))
                        spacing: Theme.spacingMicro
                        anchors.verticalCenter: parent.verticalCenter

                        Label {
                            role: "title"
                            width: parent.width
                            text: root.selectedMonitor ? root.selectedMonitor.name : ""
                            elide: Text.ElideRight
                        }

                        Label {
                            role: "caption"
                            width: parent.width
                            visible: root.selectedMonitor !== null && root.selectedMonitor.description !== ""
                            text: root.selectedMonitor ? root.selectedMonitor.description : ""
                            elide: Text.ElideRight
                        }
                    }

                    ToggleSwitch {
                        id: outputSwitch
                        visible: root.multiple
                        checked: root.selectedEnabled
                        enabled: root.selectedMonitor !== null
                            && !root.busy
                            && (root.selectedMonitor.disabled || DisplayService.draftActiveMonitors.length > 1)
                        tooltipText: checked ? "Turn display off" : "Turn display on"
                        onToggled: state => DisplayService.setSelectedEnabled(state)
                    }
                }

                // Extend and Mirror apply at once around the selected display; Single waits for Apply.
                SettingRow {
                    visible: root.multiple
                    enabled: !root.busy
                    label: "Layout"

                    SegmentedControl {
                        options: [
                            { value: "extend", label: "Extend" },
                            { value: "mirror", label: "Mirror" },
                            { value: "single", label: "Single" }
                        ]
                        currentValue: DisplayService.hasPending ? DisplayService.draftLayoutMode : DisplayService.layoutMode
                        onValueSelected: value => DisplayService.setLayout(value)
                    }
                }

                // Where the selected display sits next to another; the menu moves it there.
                SettingRow {
                    visible: root.multiple
                    enabled: root.canPositionSelected && !root.busy
                    label: "Position"

                    SelectMenu {
                        options: [
                            { value: "left", label: "Left" },
                            { value: "right", label: "Right" },
                            { value: "above", label: "Above" },
                            { value: "below", label: "Below" }
                        ]
                        fallbackLabel: root.positionLabel()
                        onValueSelected: value => DisplayService.arrangeSelected(value)
                    }
                }

                SettingRow {
                    enabled: root.selectedEnabled && root.selectedModeOptions.length > 0 && !root.busy
                    label: "Mode"

                    SelectMenu {
                        options: root.selectedModeOptions.map(mode => ({ value: mode, label: DisplayService.modeLabel(mode) }))
                        currentValue: root.selectedEnabled ? root.selectedMonitor.mode : undefined
                        fallbackLabel: !root.selectedMonitor ? "" : root.selectedMonitor.disabled ? "Off"
                            : DisplayService.modeLabel(root.selectedMonitor.mode)
                        onValueSelected: value => DisplayService.setSelectedMode(value)
                    }
                }

                BrightnessLevel {
                    visible: root.canControlSelectedBrightness
                }

                SettingRow {
                    visible: root.canControlSelectedBrightness && BatteryService.available
                    label: "On battery"
                    info: "Unplugging lowers the screen to this at most, and plugging in brings it back."

                    SegmentedControl {
                        options: [{ value: 0, label: "As is" }, { value: 30, label: "30%" },
                            { value: 50, label: "50%" }, { value: 70, label: "70%" }]
                        currentValue: BrightnessService.batteryPercent
                        onValueSelected: value => BrightnessService.setBatteryPercent(value)
                    }
                }

                // The laptop's keyboard, beside its display: a few firmware steps.
                SettingRow {
                    id: keyboardRow

                    readonly property var stepNames: [["Off", "On"], ["Off", "Low", "High"], ["Off", "Low", "Medium", "High"]]

                    visible: root.canControlSelectedBrightness && BrightnessService.keyboardAvailable
                        && BrightnessService.keyboardMax > 0
                    label: "Keyboard"
                    info: "The keyboard backlight. Dimming on idle turns it off until you're back."

                    SegmentedControl {
                        options: {
                            const names = keyboardRow.stepNames[BrightnessService.keyboardMax - 1];
                            const steps = [];
                            for (let level = 0; level <= BrightnessService.keyboardMax; level++)
                                steps.push({ value: level, label: names ? names[level]
                                    : (level === 0 ? "Off" : Math.round(level * 100 / BrightnessService.keyboardMax) + "%") });
                            return steps;
                        }
                        currentValue: BrightnessService.keyboardLevel
                        onValueSelected: value => BrightnessService.setKeyboardLevel(value)
                    }
                }
            }
        }
    }
}
