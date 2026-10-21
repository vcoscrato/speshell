pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.services
import qs.theme
import "Settings.js" as Settings
import "../../components/Format.js" as Format

// Settings › General: text size, volume scroll step, toasts on screen, the touchpad,
// and what idling does.
Column {
    id: root

    readonly property var settings: ConfigService.settings
    readonly property var textScaleOptions: [
        { value: 0.85, label: "Compact · 85%" },
        { value: 1.0, label: "Default · 100%" },
        { value: 1.1, label: "Comfortable · 110%" },
        { value: 1.2, label: "Large · 120%" },
        { value: 1.35, label: "Extra Large · 135%" },
        { value: 1.5, label: "Maximum · 150%" }
    ]
    readonly property var scrollStepOptions: [
        { value: 2, label: "2%" },
        { value: 5, label: "5%" },
        { value: 10, label: "10%" }
    ]
    // Minutes; 0 never.
    readonly property var idleOptions: [0, 1, 2, 3, 5, 6, 10, 15, 30, 60]
        .map(minutes => ({ value: minutes, label: minutes === 0 ? "Never" : Format.duration(minutes * 60) }))
    readonly property var idleSteps: [
        { key: "dimAfter", label: "Dim the screen", info: "Dims the screen and turns the keyboard backlight off." },
        { key: "lockAfter", label: "Lock", info: "Locks the session with the screen locker." },
        { key: "screenOffAfter", label: "Turn the screen off", info: "Turns the displays off, on Hyprland." },
        { key: "sleepAfter", label: "Sleep", info: "Locks and suspends. Playing media holds it off." }
    ]
    readonly property var toastOptions: [
        { value: 1, label: "1" },
        { value: 3, label: "3" },
        { value: 5, label: "5" },
        { value: 10, label: "10" },
        { value: -1, label: "All" }
    ]

    spacing: Theme.spacingSmall

    SettingRow {
        label: "Text size"
        info: "Text size in the bar, its panels, the launcher, and notifications."

        SelectMenu {
            options: root.textScaleOptions
            currentValue: root.settings.appearance.textScale
            fallbackLabel: Math.round(Number(currentValue) * 100) + "% · Custom"
            onValueSelected: value => ConfigService.setProperty("Appearance", "textScale", value)
        }
    }

    SettingRow {
        id: scrollStepRow
        readonly property int step: root.settings.audio.scrollStep

        label: "Volume scroll step"
        info: Settings.explain("How much one scroll over the bar's speaker and microphone changes their volume.",
            root.scrollStepOptions, step, step + "%")

        SegmentedControl {
            options: root.scrollStepOptions
            currentValue: scrollStepRow.step
            onValueSelected: value => ConfigService.setProperty("Audio", "scrollStep", value)
        }
    }

    SettingRow {
        id: toastsRow
        readonly property int count: root.settings.notifications.maxVisible

        label: "Toasts on screen"
        info: Settings.explain("Notifications shown at once. The oldest closes first.", root.toastOptions,
            count, String(count))

        SegmentedControl {
            options: root.toastOptions
            currentValue: toastsRow.count
            onValueSelected: value => ConfigService.setProperty("Notifications", "maxVisible", value)
        }
    }

    // Not saved: Hyprland's config turns it on again at each start.
    SettingRow {
        visible: InputService.available
        label: "Touchpad"
        info: "Turns the touchpad off until you turn it on again or Hyprland restarts. "
            + "speshell touchpad toggle does it from a key."

        ToggleSwitch {
            checked: InputService.touchpadEnabled
            tooltipText: InputService.touchpadEnabled ? "Turn the touchpad off" : "Turn the touchpad on"
            onToggled: on => InputService.setTouchpadEnabled(on)
        }
    }

    Label {
        role: "section"
        topPadding: Theme.spacingSmall
        text: "When idle on battery"
    }

    Repeater {
        model: root.idleSteps

        delegate: SettingRow {
            id: idleRow

            required property var modelData
            readonly property real minutes: root.settings.idle[idleRow.modelData.key]

            visible: idleRow.modelData.key !== "screenOffAfter" || HyprlandService.running
            label: idleRow.modelData.label
            info: Settings.explain(idleRow.modelData.info, root.idleOptions, idleRow.minutes,
                Format.duration(idleRow.minutes * 60))

            SelectMenu {
                options: root.idleOptions
                currentValue: idleRow.minutes
                fallbackLabel: Format.duration(idleRow.minutes * 60) + " · Custom"
                onValueSelected: value => ConfigService.setProperty("Idle", idleRow.modelData.key, value)
            }
        }
    }
}
