.pragma library

// Color helpers for effects, which take every color from the `theme` they receive.

// The palette a part holds as `theme` until Speshell gives it the active one, before
// it draws: Cosmos's, as Theme.qml names it.
const fallback = {
    bg: Qt.color("#282828"),
    mantle: Qt.color("#1d2021"),
    crust: Qt.color("#1b1b1b"),
    card: Qt.color("#3c3836"),
    cardHover: Qt.color("#504945"),
    surface2: Qt.color("#665c54"),
    overlay: Qt.color("#7c6f64"),
    text: Qt.color("#ebdbb2"),
    subtext: Qt.color("#bdae93"),
    subtextBright: Qt.color("#d5c4a1"),
    accent: Qt.color("#fe8019"),
    pink: Qt.color("#d3869b"),
    success: Qt.color("#b8bb26"),
    warning: Qt.color("#fabd2f"),
    error: Qt.color("#fb4934"),
    teal: Qt.color("#8ec07c"),
    sky: Qt.color("#83a598"),
    blue: Qt.color("#83a598"),
    peach: Qt.color("#fe8019"),
    yellow: Qt.color("#fabd2f"),
    rosewater: Qt.color("#ebdbb2")
};

// a blended toward b by t (0..1), opaque.
function mix(a, b, t) {
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
}

// c with alpha a.
function alpha(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a);
}
