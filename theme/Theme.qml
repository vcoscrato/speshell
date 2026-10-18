pragma Singleton
import QtQuick

QtObject {
    id: root

    // The Cosmos theme's colors (Gruvbox). Every theme starts from these, and
    // they stand in until a theme loads.
    readonly property var defaultPalette: ({
        base:     "#282828",
        mantle:   "#1d2021",
        crust:    "#1b1b1b",
        surface0: "#3c3836",
        surface1: "#504945",
        surface2: "#665c54",
        overlay0: "#7c6f64",
        text:     "#ebdbb2",
        subtext0: "#bdae93",
        subtext1: "#d5c4a1",
        pink:     "#d3869b",
        red:      "#fb4934",
        peach:    "#fe8019",
        yellow:   "#fabd2f",
        green:    "#b8bb26",
        teal:     "#8ec07c",
        sky:      "#83a598",
        blue:     "#83a598",
        rosewater:"#ebdbb2",
        accent:   "#fe8019"
    })

    // Active theme (see ThemeService): its colors merged over the default palette.
    property var paletteOverride: null

    readonly property var _p: root.mergePalette(root.paletteOverride)

    function mergePalette(colors) {
        if (!colors)
            return root.defaultPalette;
        var merged = {};
        for (const key in root.defaultPalette)
            merged[key] = colors[key] !== undefined ? colors[key] : root.defaultPalette[key];
        merged.accent = colors.accent || merged.peach;
        return merged;
    }

    // ── Colors ──────────────────────────────────────────────
    readonly property color bg:        _p.base
    readonly property color mantle:    _p.mantle
    readonly property color crust:     _p.crust
    readonly property color card:      _p.surface0
    readonly property color cardHover: _p.surface1
    readonly property color surface2:  _p.surface2
    readonly property color overlay:   _p.overlay0

    readonly property color text:      _p.text
    readonly property color subtext:   _p.subtext0
    readonly property color subtextBright: _p.subtext1

    readonly property color accent:    _p.accent
    // Text on the accent: the base or the text color, whichever reads better on it.
    readonly property color onAccent:  root.contrast(_p.accent, _p.crust) >= root.contrast(_p.accent, _p.text) ? _p.crust : _p.text

    readonly property color pink:      _p.pink

    readonly property color success:   _p.green
    readonly property color warning:   _p.yellow
    readonly property color error:     _p.red

    readonly property color teal:      _p.teal
    readonly property color sky:       _p.sky
    readonly property color blue:      _p.blue
    readonly property color peach:     _p.peach
    readonly property color yellow:    _p.yellow
    readonly property color rosewater: _p.rosewater

    // ── Typography ──────────────────────────────────────────
    readonly property string fontFamily: "Inter, Segoe UI, Roboto, sans-serif"
    property real textScale: 1.0
    readonly property int fontSizeMicro:      Math.round(9 * root.textScale)
    readonly property int fontSizeCaption:    Math.round(10 * root.textScale)
    readonly property int fontSizeSmall:      Math.round(11 * root.textScale)
    readonly property int fontSizeSupporting: Math.round(12 * root.textScale)
    readonly property int fontSizeNormal:     Math.round(13 * root.textScale)
    readonly property int fontSizeLarge:      Math.round(16 * root.textScale)
    readonly property int fontSizeTitle:      Math.round(20 * root.textScale)
    readonly property int fontSizeHuge:       Math.round(40 * root.textScale)

    // Icons are geometry, not typography. Keep them stable when only text scales.
    readonly property int iconSizeTiny:   12   // inline markers and chevrons
    readonly property int iconSizeSmall:  14   // card headers, compact buttons
    readonly property int iconSizeMedium: 18   // row icons, standard buttons
    readonly property int iconSizeLarge:  24   // launcher results, OSDs, primary actions

    // ── Spacing ─────────────────────────────────────────────
    readonly property int spacingMicro:  2     // stacked title/subtitle lines
    readonly property int spacingTiny:   4
    readonly property int spacingSmall:  8
    readonly property int spacingMedium: 12
    readonly property int spacingLarge:  16
    readonly property int spacingXL:     24
    readonly property int panelPadding:  root.spacingMedium

    // ── Controls ────────────────────────────────────────────
    // Floors: controls holding text still grow with textScale.
    readonly property int controlHeightSmall: 24   // tabs, compact and header buttons
    readonly property int controlHeight:      32   // rows, fields, sliders, buttons

    // ── Geometry ────────────────────────────────────────────
    readonly property int borderRadius:      4
    readonly property int borderRadiusSmall: 3
    readonly property int surfaceCornerCut:  16
    readonly property int borderWidth:       1

    // ── Interaction states ──────────────────────────────────
    // Neutral controls rest on controlFill/controlBorder and use cardHover on hover.
    // Tone-colored controls tint their tone: tintSubtle at rest, tintStrong when
    // hovered, armed, or selected among filled siblings, tintOutline for borders
    // (tintOutlineStrong when armed or selected).
    readonly property real tintSubtle:  0.12
    readonly property real tintStrong:  0.2
    readonly property real tintOutline: 0.45
    readonly property real tintOutlineStrong: 0.85
    readonly property real disabledOpacity: 0.45
    readonly property color controlFill:    root.alpha(root.overlay, root.tintSubtle)
    readonly property color controlBorder:  root.alpha(root.overlay, 0.24)
    readonly property color selectedFill:   root.alpha(root.accent, root.tintSubtle)
    readonly property color selectedBorder: root.alpha(root.accent, root.tintOutline)

    // ── Animation ───────────────────────────────────────────
    // Off in power saver: transitions jump to their end and nothing pulses or blinks.
    property bool motion: true
    readonly property int animDurationFast: root.motion ? 100 : 0
    readonly property int animDuration:     root.motion ? 200 : 0
    readonly property int animDurationSlow: root.motion ? 350 : 0
    readonly property int animEasing:       Easing.OutCubic

    // ── Layout ──────────────────────────────────────────────
    // A bar dropdown's content; wider text gets wider panels.
    readonly property int panelWidth: Math.round(340 * Math.max(1, root.textScale))
    // Surfaces paint the theme's backdrop at least this tall and show its top.
    readonly property int backdropHeight:     1050
    readonly property int separatorThickness: 1
    readonly property color separator:        root.alpha(root.surface2, 0.72)

    // ── Helpers ─────────────────────────────────────────────
    function alpha(color, value) {
        return Qt.rgba(color.r, color.g, color.b, value);
    }

    // WCAG contrast ratio of two colors, 1 to 21.
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

    function toneColor(tone) {
        if (tone === "success") return root.success;
        if (tone === "warning") return root.warning;
        if (tone === "error") return root.error;
        if (tone === "accent") return root.accent;
        return root.overlay;
    }
}
