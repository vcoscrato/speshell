.pragma library
.import "common/Colors.js" as Colors

// Sugar's colors, from a theme (`theme` as Theme.qml names it); the Sugar palette's own
// before a theme arrives.

// Frosting: the accent, lit and shaded.
function frosting(theme) {
    return theme ? theme.accent : "#f483ad";
}

function frostingLight(theme) {
    return theme ? Colors.mix(theme.accent, theme.text, 0.55) : "#f9bdd2";
}

function frostingShade(theme) {
    return theme ? Colors.mix(theme.accent, theme.crust, 0.3) : "#b05f7e";
}

// Vanilla cream, and the sponge inside a cake.
function cream(theme) {
    return theme ? Colors.mix(theme.text, theme.yellow, 0.18) : "#fbe8c9";
}

function sponge(theme) {
    return theme ? Colors.mix(Colors.mix(theme.yellow, theme.peach, 0.35), theme.text, 0.25) : "#fdcf88";
}

// Chocolate, and the darkest of it, for shadows and soft edges.
function chocolate(theme) {
    return theme ? Colors.mix(theme.bg, theme.peach, 0.12) : "#3f2a22";
}

function ink(theme) {
    return theme ? theme.crust : "#1a110f";
}

// Sugar's sparkle, brighter than any theme color.
function sparkle(theme) {
    return theme ? Qt.lighter(theme.text, 1.04) : "#fff6ee";
}

// Gold, for leaf and dragées.
function gold(theme) {
    return theme ? Colors.mix(theme.yellow, theme.peach, 0.3) : "#ffc570";
}

// A spatula's wooden handle.
function wood(theme) {
    return theme ? Colors.mix(theme.peach, theme.bg, 0.45) : "#94604b";
}

// A piping bag's nozzle.
function metal(theme) {
    return theme ? Colors.mix(theme.subtext, theme.text, 0.35) : "#dcc8bc";
}

function metalShade(theme) {
    return theme ? Colors.mix(theme.overlay, theme.bg, 0.2) : "#76594f";
}
