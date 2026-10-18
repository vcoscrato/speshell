.pragma library
.import "common/Colors.js" as Colors

// Water's colors, from a theme's blues (`theme` as Theme.qml names it); the Water
// palette's own before a theme arrives.

function deep(theme) {
    return theme ? Colors.mix(theme.accent, theme.bg, 0.45) : "#1d5f8c";
}

function mid(theme) {
    return theme ? Colors.mix(theme.accent, theme.crust, 0.1) : "#2f8fc4";
}

function light(theme) {
    return theme ? theme.sky : "#7cc9ea";
}

// Foam and spray, brighter than any theme color.
function foam(theme) {
    return theme ? Qt.lighter(Colors.mix(theme.text, theme.sky, 0.2), 1.15) : "#f2fbff";
}
