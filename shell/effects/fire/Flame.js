.pragma library
.import "common/Colors.js" as Colors

// Fire's colors, from a theme's warm colors (`theme` as Theme.qml names it). Flames burn brighter than any theme color.

function core(theme) {
    return Qt.lighter(Colors.mix(theme.accent, theme.text, 0.2), 1.5);
}

function mid(theme) {
    return Qt.lighter(Colors.mix(theme.accent, theme.peach, 0.35), 1.05);
}

function outer(theme) {
    return Colors.mix(theme.error, theme.peach, 0.2);
}

function edge(theme) {
    return Colors.mix(theme.error, theme.crust, 0.35);
}

// The glow ahead of a burn front.
function glow(theme) {
    return theme.peach;
}

// The char band behind a burn front; deeper over the wallpaper.
function charred(theme, deep) {
    return Colors.mix(theme.crust, theme.error, deep ? 0.1 : 0.2);
}

// The scorch on what a burn front is about to consume.
function scorch(theme) {
    return Colors.mix(theme.crust, theme.peach, 0.3);
}
