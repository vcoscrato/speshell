.pragma library
.import "common/Colors.js" as Colors

// Relâmpago's colors, from a theme (`theme` as Theme.qml names it); the Relâmpago
// palette's own before a theme arrives. Lightning burns brighter than any theme color.

// A bolt's white-hot core.
function core(theme) {
    return theme ? Qt.lighter(Colors.mix(theme.yellow, theme.text, 0.55), 1.15) : "#fff8dc";
}

// The yellow glow around it, and its orange outer edge.
function glow(theme) {
    return theme ? theme.yellow : "#ffcc24";
}

function edge(theme) {
    return theme ? theme.peach : "#ff8a1f";
}

// The racing red of the paint.
function paint(theme) {
    return theme ? theme.accent : "#e4252b";
}

// Tires, skid marks, and outlines.
function rubber(theme) {
    return theme ? theme.crust : "#0d0c0e";
}

// Tire smoke, lit and shaded.
function smoke(theme) {
    return theme ? Colors.mix(theme.subtext, theme.text, 0.25) : "#c4b9b5";
}

function smokeShade(theme) {
    return theme ? Colors.mix(theme.overlay, theme.bg, 0.25) : "#58505a";
}
