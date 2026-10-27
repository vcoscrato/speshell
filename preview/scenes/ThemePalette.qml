import QtQuick
import Quickshell
import Quickshell.Io

// Theme.qml's color names, from the [Colors] of the theme.ini at THEME_INI (Cosmos fills
// the gaps), for scenes that stand in for Speshell's own surfaces.
QtObject {
    id: palette

    property FileView file: FileView {
        path: Quickshell.env("THEME_INI") || ""
        blockLoading: true
    }

    readonly property var c: {
        const colors = { base: "#282828", mantle: "#1d2021", crust: "#1b1b1b", surface0: "#3c3836",
                         surface1: "#504945", surface2: "#665c54", overlay0: "#7c6f64", text: "#ebdbb2",
                         subtext0: "#bdae93", subtext1: "#d5c4a1", red: "#fb4934", peach: "#fe8019",
                         yellow: "#fabd2f", green: "#b8bb26", teal: "#8ec07c", sky: "#83a598",
                         blue: "#83a598", pink: "#d3869b", rosewater: "#ebdbb2", accent: "" };
        for (const line of String(palette.file.text()).split("\n")) {
            const m = line.match(/^\s*(\w+)\s*=\s*(#[0-9a-fA-F]{6})/);
            if (m && m[1] in colors)
                colors[m[1]] = m[2];
        }
        colors.accent = colors.accent || colors.peach;
        return colors;
    }
    readonly property color bg: c.base
    readonly property color mantle: c.mantle
    readonly property color crust: c.crust
    readonly property color card: c.surface0
    readonly property color cardHover: c.surface1
    readonly property color surface2: c.surface2
    readonly property color overlay: c.overlay0
    readonly property color text: c.text
    readonly property color subtext: c.subtext0
    readonly property color subtextBright: c.subtext1
    readonly property color accent: c.accent
    readonly property color onAccent: palette.contrast(c.accent, c.crust) >= palette.contrast(c.accent, c.text) ? c.crust : c.text
    readonly property color pink: c.pink
    readonly property color success: c.green
    readonly property color warning: c.yellow
    readonly property color error: c.red
    readonly property color teal: c.teal
    readonly property color sky: c.sky
    readonly property color blue: c.blue
    readonly property color peach: c.peach
    readonly property color yellow: c.yellow
    readonly property color rosewater: c.rosewater

    // As Theme.qml's.
    function contrast(first, second) {
        const luminance = value => {
            const color = Qt.color(value);
            const linear = channel => channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4);
            return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b);
        };
        const a = luminance(first);
        const b = luminance(second);
        return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
    }
}
