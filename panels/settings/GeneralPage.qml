import QtQuick
import qs.components
import qs.services
import qs.theme
import "Settings.js" as Settings

Column {
    id: root

    readonly property var config: ConfigService.config ?? ({})
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
            currentValue: root.config.textScale ?? 1.0
            fallbackLabel: Math.round(Number(currentValue) * 100) + "% · Custom"
            onValueSelected: value => ConfigService.setProperty("Appearance", "textScale", value)
        }
    }

    SettingRow {
        id: scrollStepRow
        readonly property int step: root.config.audioScrollStep ?? 5

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
        readonly property int count: root.config.maxVisibleNotification ?? 3

        label: "Toasts on screen"
        info: Settings.explain("Notifications shown at once. The oldest closes first.", root.toastOptions,
            count, String(count))

        SegmentedControl {
            options: root.toastOptions
            currentValue: toastsRow.count
            onValueSelected: value => ConfigService.setProperty("Notifications", "maxVisible", value)
        }
    }
}
