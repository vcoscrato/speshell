.pragma library
.import "common/Colors.js" as Colors

// Fire's colors, from a theme's warm colors (`theme` as Theme.qml names it); the Fire
// palette's own before a theme arrives. Flames burn brighter than any theme color.

function core(theme) {
    return theme ? Qt.lighter(Colors.mix(theme.accent, theme.text, 0.2), 1.5) : "#fff6c8";
}

function mid(theme) {
    return theme ? Qt.lighter(Colors.mix(theme.accent, theme.peach, 0.35), 1.05) : "#ffb02e";
}

function outer(theme) {
    return theme ? Colors.mix(theme.error, theme.peach, 0.2) : "#f2541b";
}

function edge(theme) {
    return theme ? Colors.mix(theme.error, theme.crust, 0.35) : "#a8160f";
}

// The glow ahead of a burn front.
function glow(theme) {
    return theme ? theme.peach : "#ff8a1f";
}

// The char band behind a burn front; deeper over the wallpaper.
function charred(theme, deep) {
    return theme ? Colors.mix(theme.crust, theme.error, deep ? 0.1 : 0.2) : (deep ? "#2a0e09" : "#3a120c");
}

// The scorch on what a burn front is about to consume.
function scorch(theme) {
    return theme ? Colors.mix(theme.crust, theme.peach, 0.3) : Qt.rgba(0.36, 0.2, 0.1, 1);
}
