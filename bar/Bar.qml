pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import qs.components
import qs.services
import qs.theme

// Speshell's bar, one per screen, along its top or bottom: the Speshell mark, which
// opens the launcher, and the screen's workspaces; the clock between the playing track
// and the weather, the timers, and what's running (dictation, a recording); the tray
// and the panel buttons. Buttons open their panel in a dropdown, and each timer its own.
//
// The window covers the screen so dropdowns, menus, and labels can draw beside the
// bar, and takes input only on the bar until one of them opens.
PanelWindow {
    id: root

    required property var modelData
    property var config: null

    // [Bar] position, height, width (percent of the screen), margin (from the screen's
    // edge; 0 docks the bar there), gap (to the windows), and outline.
    readonly property var settings: root.config
        ? root.config.bar
        : ({ position: "top", height: 40, width: 100, margin: 0, gap: 0, outline: "edges" })
    readonly property bool atTop: root.settings.position !== "bottom"
    readonly property bool docked: root.settings.margin === 0
    readonly property bool fullWidth: strip.width >= root.width
    readonly property string screenName: root.modelData ? root.modelData.name : ""
    // Buttons fill the bar, short of the controls' usual height.
    readonly property int itemSize: Math.min(Theme.controlHeight, root.settings.height - Theme.spacingMicro * 2)
    // As much space beside the end buttons as above and below them.
    readonly property int edgePadding: Math.max(Theme.spacingTiny, (root.settings.height - root.itemSize) / 2)
    // The panel buttons, left to right, in groups: tools, status, and Speshell itself.
    readonly property var panelGroups: [
        ["tools", "clipboard", "notes"],
        ["audio", "microphone", "display", "network", "bluetooth", "battery", "notifications"],
        ["settings", "power"]
    ]

    // The panel open in the dropdown, or "", and the button it hangs from.
    readonly property string openPanel: dropdown.panel
    readonly property Item dropdownButton: dropdown.button
    readonly property bool dropdownOpen: root.openPanel !== ""
    property int openMenus: 0
    readonly property bool overlayOpen: root.dropdownOpen || root.openMenus > 0

    onDropdownOpenChanged: PanelService.openDropdowns += root.dropdownOpen ? 1 : -1
    Component.onDestruction: if (root.dropdownOpen) PanelService.openDropdowns -= 1

    // `pointer`: the MouseArea clicked, or null from the keyboard.
    function toggleDropdown(panel, button, pointer) {
        if (dropdown.panel === panel && dropdown.button === button) {
            root.closeDropdown();
            return;
        }
        EffectsService.picked(button, pointer || null);
        dropdown.button = button;
        dropdown.panel = panel;
    }

    function closeDropdown() {
        dropdown.panel = "";
        dropdown.button = null;
    }

    // The button that opens `panel`, or null.
    function buttonFor(panel) {
        if (panel === "clock")
            return clockButton;
        if (panel === "weather")
            return weatherButton.visible ? weatherButton : null;
        if (panel === "media")
            return media.visible ? media.coverButton : null;
        // The newest timer.
        if (panel === "timer")
            return timerChips.count > 0 ? timerChips.itemAt(timerChips.count - 1) : null;
        for (let i = 0; i < panelButtons.count; i++) {
            const button = (panelButtons.itemAt(i) as Row).buttonFor(panel);
            if (button)
                return button;
        }
        return null;
    }

    function step(panel, direction) {
        if (panel === "audio")
            AudioService.stepOutputVolume(direction);
        else if (panel === "microphone")
            AudioService.stepInputVolume(direction);
        else if (panel === "display")
            BrightnessService.stepPercent(direction);
    }

    function cycleDevice(panel) {
        if (panel === "audio")
            AudioService.cycleOutputDevice();
        else if (panel === "microphone")
            AudioService.cycleInputDevice();
    }

    screen: root.modelData
    anchors {
        top: root.atTop
        bottom: !root.atTop
        left: true
        right: true
    }
    implicitHeight: root.modelData ? root.modelData.height : 0
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: root.settings.margin + root.settings.height + root.settings.gap
    mask: Region { item: root.overlayOpen ? content : strip }

    WlrLayershell.namespace: "speshell-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.dropdownOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Connections {
        target: PanelService

        function onRequested(panel, screen, toggle) {
            if (screen !== root.screenName)
                return;
            const button = root.buttonFor(panel);
            if (toggle && dropdown.panel === panel)
                root.closeDropdown();
            else if (dropdown.panel !== panel || dropdown.button !== button)
                root.toggleDropdown(panel, button, null);
        }

        function onDismissRequested() {
            root.closeDropdown();
        }
    }

    Item {
        id: content
        anchors.fill: parent

        // Closes the dropdown on a click anywhere outside it.
        MouseArea {
            anchors.fill: parent
            enabled: root.dropdownOpen
            onPressed: root.closeDropdown()
        }

        Item {
            id: strip

            // The clock stays centered unless a side crowds it, with the track's
            // controls before it and the weather and the timers after. Short of
            // room, the bar grows wider than its setting rather than overlap or drop
            // anything.
            readonly property real gap: Theme.spacingMedium
            readonly property real middleStart: leftRow.x + leftRow.width + strip.gap
            readonly property real middleEnd: rightRow.x - strip.gap
            readonly property real beforeClock: media.visible ? media.width + Theme.spacingTiny : 0
            readonly property real afterClock: afterClockRow.width > 0 ? afterClockRow.width + Theme.spacingTiny : 0
            readonly property real requiredWidth: root.edgePadding * 2 + leftRow.width + rightRow.width
                + strip.gap * 2 + strip.beforeClock + clockButton.width + strip.afterClock

            x: Math.round((root.width - width) / 2)
            y: root.atTop ? root.settings.margin : root.height - root.settings.margin - root.settings.height
            width: Math.min(root.width, Math.max(Math.round(root.width * root.settings.width / 100),
                Math.ceil(strip.requiredWidth)))
            height: root.settings.height

            // Square, like the windows around it. Framed on every side that doesn't touch the
            // screen's edge, where the frame runs off screen; with the full outline, framed
            // there too, moved in by half the frame's stroke so it shows whole.
            Surface {
                readonly property int screenEdgeMargin: root.settings.outline === "full" ? 1 : -2

                anchors.fill: parent
                anchors.topMargin: root.docked && root.atTop ? screenEdgeMargin : 0
                anchors.bottomMargin: root.docked && !root.atTop ? screenEdgeMargin : 0
                anchors.leftMargin: root.fullWidth ? screenEdgeMargin : 0
                anchors.rightMargin: root.fullWidth ? screenEdgeMargin : 0
                backdrop: true
            }

            // ── The mark, opening the launcher, and this screen's workspaces ──
            Row {
                id: leftRow
                anchors.left: parent.left
                anchors.leftMargin: root.edgePadding
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingTiny

                BarButton {
                    id: markButton
                    size: root.itemSize
                    labelAbove: !root.atTop
                    open: LauncherService.shown
                    label: "Launcher"
                    onClicked: pointer => {
                        EffectsService.picked(markButton, pointer);
                        root.closeDropdown();
                        LauncherService.toggle();
                    }

                    // Drawn on a 29 px grid; crisp at that size, scaled down in short bars.
                    SpeshellMark {
                        anchors.centerIn: parent
                        size: Math.min(29, root.itemSize - Theme.spacingTiny)
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: workspaces.visible
                    width: Theme.separatorThickness
                    height: Math.min(Theme.controlHeightSmall, root.itemSize)
                    color: Theme.separator
                }

                Workspaces {
                    id: workspaces
                    anchors.verticalCenter: parent.verticalCenter
                    screenName: root.screenName
                    itemSize: root.itemSize
                    labelAbove: !root.atTop
                    visible: WorkspaceService.available
                }
            }

            // ── The clock, opening the clock panel, between the playing track and the
            // weather, the timers, and what's running ──
            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

            BarButton {
                id: clockButton
                size: root.itemSize
                labelAbove: !root.atTop
                x: Math.max(strip.middleStart + strip.beforeClock, Math.min(strip.middleEnd - strip.afterClock - width,
                    Math.round((strip.width - width) / 2)))
                anchors.verticalCenter: parent.verticalCenter
                open: root.dropdownButton === clockButton
                horizontalPadding: Theme.spacingLarge
                text: Qt.formatDateTime(clock.date, "ddd d MMM") + "   " + Qt.formatDateTime(clock.date, "HH:mm")
                fontSize: Theme.fontSizeNormal
                fontWeight: Font.DemiBold
                onClicked: pointer => root.toggleDropdown("clock", clockButton, pointer)
            }

            MediaControls {
                id: media
                itemSize: root.itemSize
                labelAbove: !root.atTop
                coverOpen: root.dropdownButton === media.coverButton
                onCoverClicked: pointer => root.toggleDropdown("media", media.coverButton, pointer)
                anchors.right: clockButton.left
                anchors.rightMargin: Theme.spacingTiny
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                id: afterClockRow
                anchors.left: clockButton.right
                anchors.leftMargin: Theme.spacingTiny
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingTiny

                BarButton {
                    id: weatherButton
                    size: root.itemSize
                    labelAbove: !root.atTop
                    // Also with an unknown location, to open the panel that changes it, and
                    // while open, as a new location loads.
                    visible: WeatherService.ready || WeatherService.status === "unknown" || open
                    open: root.dropdownButton === weatherButton
                    label: PanelService.status("weather")
                    iconName: PanelService.icon("weather")
                    text: WeatherService.ready ? WeatherService.temperatureText(WeatherService.current.temperature) : ""
                    tabularDigits: true
                    onClicked: pointer => root.toggleDropdown("weather", weatherButton, pointer)
                }

                // The timers, each opening to set or control it, and what's running, in a
                // well of their own.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: timerChips.count + activityChips.count > 0
                    width: timerRow.implicitWidth + Theme.spacingMicro * 2
                    height: root.itemSize
                    radius: Theme.borderRadius
                    color: Theme.controlFill
                    border.width: Theme.borderWidth
                    border.color: Theme.controlBorder

                    Row {
                        id: timerRow
                        anchors.centerIn: parent

                        Repeater {
                            id: timerChips
                            model: TimerService.timers

                            delegate: TimerChip {
                                id: chip

                                required property var modelData

                                timer: chip.modelData
                                size: root.itemSize - Theme.spacingMicro * 2
                                labelAbove: !root.atTop
                                open: root.dropdownButton === chip
                                onClicked: pointer => root.toggleDropdown("timer", chip, pointer)
                            }
                        }

                        Repeater {
                            id: activityChips
                            model: ActivityService.activities

                            delegate: ActivityChip {
                                required property var modelData

                                activity: modelData
                                size: root.itemSize - Theme.spacingMicro * 2
                                labelAbove: !root.atTop
                            }
                        }
                    }
                }
            }

            // ── Tray and panel buttons ──
            Row {
                id: rightRow
                anchors.right: parent.right
                anchors.rightMargin: root.edgePadding
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingTiny

                // Other apps' icons, in a well of their own.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: trayRepeater.count > 0
                    width: trayRow.implicitWidth + Theme.spacingTiny * 2
                    height: root.itemSize
                    radius: Theme.borderRadius
                    color: Theme.controlFill
                    border.width: Theme.borderWidth
                    border.color: Theme.controlBorder

                    Row {
                        id: trayRow
                        anchors.centerIn: parent
                        // Items are spacingTiny narrower than the panel buttons, so
                        // twice the spacing keeps the same icon pitch.
                        spacing: Theme.spacingSmall

                        Repeater {
                            id: trayRepeater
                            model: SystemTray.items

                            delegate: TrayItem {
                                width: root.itemSize - Theme.spacingTiny
                                height: root.itemSize - Theme.spacingTiny
                                above: !root.atTop
                                onMenuOpenChanged: root.openMenus = Math.max(0, root.openMenus + (menuOpen ? 1 : -1))
                                Component.onDestruction: if (menuOpen) root.openMenus = Math.max(0, root.openMenus - 1)
                            }
                        }
                    }
                }

                Repeater {
                    id: panelButtons
                    model: root.panelGroups

                    delegate: Row {
                        id: group

                        required property var modelData
                        required property int index

                        function buttonFor(panel) {
                            for (let i = 0; i < groupButtons.count; i++) {
                                const button = groupButtons.itemAt(i) as BarButton;
                                if (button.panel === panel)
                                    return button.visible ? button : null;
                            }
                            return null;
                        }

                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingTiny

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: group.index > 0
                            width: Theme.separatorThickness
                            height: Math.min(Theme.controlHeightSmall, root.itemSize)
                            color: Theme.separator
                        }

                        Repeater {
                            id: groupButtons
                            model: group.modelData

                            delegate: BarButton {
                                id: button

                                required property string modelData

                                size: root.itemSize
                                labelAbove: !root.atTop
                                panel: button.modelData
                                visible: PanelService.isSupported(button.modelData)
                                open: root.dropdownButton === button
                                label: PanelService.status(button.modelData)
                                iconName: PanelService.icon(button.modelData)
                                onClicked: pointer => root.toggleDropdown(button.modelData, button, pointer)
                                onWheeled: delta => root.step(button.modelData, delta)
                                onRightClicked: root.cycleDevice(button.modelData)

                                // Unread notifications.
                                Rectangle {
                                    visible: button.modelData === "notifications"
                                        && NotificationService.notificationHistory.length > 0
                                    x: parent.width - width - Theme.spacingTiny
                                    y: Theme.spacingTiny
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: Theme.accent
                                }
                            }
                        }
                    }
                }
            }
        }

        Dropdown {
            id: dropdown
            barRect: Qt.rect(strip.x, strip.y, strip.width, strip.height)
            atTop: root.atTop
            shown: root.visible
            onCloseRequested: root.closeDropdown()
        }

        // The theme effects' interactions over the bar and its dropdown.
        InteractionsLayer {
            z: 200
            anchors.fill: parent
            host: content
            presented: root.visible
        }
    }
}
