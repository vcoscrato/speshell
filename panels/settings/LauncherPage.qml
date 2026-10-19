import QtQuick
import qs.components
import qs.services
import qs.theme
import "Settings.js" as Settings

// Settings › Launcher: visible results, width, and the web search engine.
Column {
    id: root

    readonly property var launcher: ConfigService.settings.launcher
    readonly property var rowOptions: [
        { value: 3, label: "3" },
        { value: 5, label: "5" },
        { value: 7, label: "7" },
        { value: 10, label: "10" }
    ]
    readonly property var widthOptions: [
        { value: 420, label: "Compact · 420 px" },
        { value: 540, label: "Default · 540 px" },
        { value: 680, label: "Wide · 680 px" },
        { value: 800, label: "Extra Wide · 800 px" }
    ]
    readonly property var searchOptions: [
        { value: "https://duckduckgo.com/?q={query}", label: "DuckDuckGo" },
        { value: "https://www.google.com/search?q={query}", label: "Google" },
        { value: "https://searx.be/search?q={query}", label: "SearXNG" },
        { value: "https://www.bing.com/search?q={query}", label: "Bing" }
    ]

    spacing: Theme.spacingSmall

    SettingRow {
        id: rowsRow
        readonly property int rows: root.launcher.visibleRows

        label: "Visible results"
        info: Settings.explain("Results shown before the list scrolls.", root.rowOptions, rows, rows + " rows")

        SegmentedControl {
            options: root.rowOptions
            currentValue: rowsRow.rows
            onValueSelected: value => ConfigService.setProperty("Launcher", "visibleRows", value)
        }
    }

    SettingRow {
        label: "Width"

        SelectMenu {
            options: root.widthOptions
            currentValue: root.launcher.width
            fallbackLabel: currentValue + " px · Custom"
            onValueSelected: value => ConfigService.setProperty("Launcher", "width", value)
        }
    }

    SettingRow {
        label: "Web search"
        info: "Used for ? searches. Other search engines can be set in config.ini."

        SelectMenu {
            options: root.searchOptions
            currentValue: root.launcher.searchUrl
            fallbackLabel: "Custom URL"
            onValueSelected: value => ConfigService.setProperty("Launcher", "searchUrl", value)
        }
    }
}
