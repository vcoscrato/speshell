.pragma library
.import "common/Colors.js" as Colors

// Relâmpago's colors, from a theme (`theme` as Theme.qml names it). Lightning burns brighter than any theme color.

// A bolt's white-hot core.
function core(theme) {
    return Qt.lighter(Colors.mix(theme.yellow, theme.text, 0.55), 1.15);
}

// The yellow glow around it, and its orange outer edge.
function glow(theme) {
    return theme.yellow;
}

function edge(theme) {
    return theme.peach;
}

// The racing red of the paint.
function paint(theme) {
    return theme.accent;
}

// Tires, skid marks, and outlines.
function rubber(theme) {
    return theme.crust;
}

// Tire smoke, lit and shaded.
function smoke(theme) {
    return Colors.mix(theme.subtext, theme.text, 0.25);
}

function smokeShade(theme) {
    return Colors.mix(theme.overlay, theme.bg, 0.25);
}
