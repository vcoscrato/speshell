.pragma library
.import "common/Colors.js" as Colors

// Water's colors, from a theme's blues (`theme` as Theme.qml names it).

function deep(theme) {
    return Colors.mix(theme.accent, theme.bg, 0.45);
}

function mid(theme) {
    return Colors.mix(theme.accent, theme.crust, 0.1);
}

function light(theme) {
    return theme.sky;
}

// Foam and spray, brighter than any theme color.
function foam(theme) {
    return Qt.lighter(Colors.mix(theme.text, theme.sky, 0.2), 1.15);
}
