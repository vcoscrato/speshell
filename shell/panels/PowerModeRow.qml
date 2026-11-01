import QtQuick
import qs.components
import qs.services

// PowerService's mode, in the Battery panel, or the Power panel without a battery.
SettingRow {
    label: "Power mode"
    info: (PowerService.profilesAvailable
            ? "Sets the system's power profile and Speshell's animations together."
            : "Sets how much Speshell animates.")
        + (PowerService.onSaver ? " Picked now, it lasts until plugged in." : "")

    SegmentedControl {
        options: [
            { value: "saver", label: "Saver" },
            { value: "balanced", label: "Balanced" },
            { value: "maximum", label: "Maximum" }
        ]
        currentValue: PowerService.mode
        onValueSelected: value => PowerService.setMode(value)
    }
}
