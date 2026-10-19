pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.services
import qs.theme

// Settings › Bar: its position, sizes, and outline.
Column {
    id: root

    readonly property var bar: ConfigService.settings.bar
    readonly property var positionOptions: [
        { value: "top", label: "Top" },
        { value: "bottom", label: "Bottom" }
    ]
    // The bar's sizes, each with the values offered.
    readonly property var sizes: [
        { key: "height", label: "Height", unit: " px",
          options: [24, 28, 32, 36, 40, 44, 48, 56, 64].map(px => ({ value: px, label: px + " px" })) },
        { key: "width", label: "Width", unit: "%",
          options: [25, 33, 50, 66, 75, 90, 100].map(percent => ({ value: percent, label: percent >= 100 ? "Full" : percent + "%" })) },
        { key: "margin", label: "Margin", unit: " px",
          options: [0, 2, 4, 8, 12, 16, 24, 32].map(px => ({ value: px, label: px === 0 ? "Docked" : px + " px" })) },
        { key: "gap", label: "Gap", unit: " px",
          options: [0, 1, 2, 4, 6, 8, 12, 16].map(px => ({ value: px, label: px + " px" })) }
    ]

    spacing: Theme.spacingSmall

    SettingRow {
        label: "Position"
        info: "The screen edge the bar runs along. Margin is its distance from that edge, and gap the space between it and the windows."

        SegmentedControl {
            options: root.positionOptions
            currentValue: root.bar.position
            onValueSelected: value => ConfigService.setProperty("Bar", "position", value)
        }
    }

    Grid {
        id: sizeGrid
        readonly property real columnWidth: (width - columnSpacing) / 2

        width: parent.width
        columns: 2
        columnSpacing: Theme.spacingMedium
        rowSpacing: Theme.spacingSmall

        Repeater {
            model: root.sizes

            Column {
                id: size

                required property var modelData
                readonly property var current: root.bar[size.modelData.key]

                width: sizeGrid.columnWidth
                spacing: Theme.spacingTiny

                Label {
                    role: "caption"
                    text: size.modelData.label
                }

                SelectMenu {
                    width: parent.width
                    options: size.modelData.options
                    currentValue: size.current
                    fallbackLabel: size.current + size.modelData.unit
                    onValueSelected: value => ConfigService.setProperty("Bar", size.modelData.key, value)
                }
            }
        }
    }

    SettingRow {
        label: "Full outline"
        info: "Frame the bar along the screen's edges too, not only on the sides away from them."

        ToggleSwitch {
            checked: root.bar.outline === "full"
            tooltipText: "Full outline"
            onToggled: on => ConfigService.setProperty("Bar", "outline", on ? "full" : "edges")
        }
    }
}
