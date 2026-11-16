.pragma library
.import "common/Colors.js" as Colors

// Sugar's colors, from a theme (`theme` as Theme.qml names it).

// Frosting: the accent, lit and shaded.
function frosting(theme) {
    return theme.accent;
}

function frostingLight(theme) {
    return Colors.mix(theme.accent, theme.text, 0.55);
}

function frostingShade(theme) {
    return Colors.mix(theme.accent, theme.crust, 0.3);
}

// Vanilla cream, and the sponge inside a cake.
function cream(theme) {
    return Colors.mix(theme.text, theme.yellow, 0.18);
}

function creamShade(theme) {
    return Colors.mix(cream(theme), chocolate(theme), 0.3);
}

function sponge(theme) {
    return Colors.mix(Colors.mix(theme.yellow, theme.peach, 0.35), theme.text, 0.25);
}

// Choux pastry, baked golden, and browner where it baked most.
function choux(theme) {
    return Colors.mix(sponge(theme), chocolate(theme), 0.42);
}

function chouxDeep(theme) {
    return Colors.mix(sponge(theme), chocolate(theme), 0.72);
}

// Chocolate, and the darkest of it, for shadows and soft edges.
function chocolate(theme) {
    return Colors.mix(theme.bg, theme.peach, 0.12);
}

function chocolateDark(theme) {
    return Colors.mix(chocolate(theme), theme.crust, 0.55);
}

function ink(theme) {
    return theme.crust;
}

// Sugar's sparkle, brighter than any theme color.
function sparkle(theme) {
    return Qt.lighter(theme.text, 1.04);
}

// Raspberry, from the theme's red, lit and in shadow.
function berry(theme) {
    return Colors.mix(theme.error, theme.crust, 0.12);
}

function berryDeep(theme) {
    return Colors.mix(theme.error, theme.crust, 0.6);
}

function berryLight(theme) {
    return Colors.mix(theme.error, theme.text, 0.3);
}

// A cherry's stem, green turning to wood.
function stem(theme) {
    return Colors.mix(theme.success, wood(theme), 0.55);
}

// Gold, for leaf and dragées.
function gold(theme) {
    return Colors.mix(theme.yellow, theme.peach, 0.3);
}

function goldShade(theme) {
    return Colors.mix(gold(theme), chocolate(theme), 0.5);
}

// A spatula's wooden handle.
function wood(theme) {
    return Colors.mix(theme.peach, theme.bg, 0.45);
}

// A piping bag's nozzle.
function metal(theme) {
    return Colors.mix(theme.subtext, theme.text, 0.35);
}

function metalShade(theme) {
    return Colors.mix(theme.overlay, theme.bg, 0.2);
}
