.pragma library
.import "common/Colors.js" as Colors

// Christmas's colors, from a theme (`theme` as Theme.qml names it).

// Fresh snow, lit by the moon, and in shade.
function snow(theme) {
    return Colors.mix(theme.text, theme.sky, 0.12);
}

function snowShade(theme) {
    return Colors.mix(Colors.mix(theme.text, theme.blue, 0.4), theme.bg, 0.35);
}

// Clear ice and frost.
function ice(theme) {
    return Colors.mix(theme.sky, theme.text, 0.35);
}

// Fir needles: lit, mid, and deep in a bough.
function pineLight(theme) {
    return Colors.mix(theme.success, theme.teal, 0.25);
}

function pine(theme) {
    return Colors.mix(theme.success, theme.crust, 0.5);
}

function pineDeep(theme) {
    return Colors.mix(theme.success, theme.crust, 0.75);
}

// Holly berries and cranberry red.
function berry(theme) {
    return theme.error;
}

function berryDeep(theme) {
    return Colors.mix(theme.error, theme.crust, 0.45);
}

function berryLight(theme) {
    return Colors.mix(theme.error, theme.text, 0.35);
}

// Holly leaves: glossy, darker and warmer than fir, and their sheen.
function holly(theme) {
    return Colors.mix(theme.success, theme.crust, 0.4);
}

function hollyLight(theme) {
    return Colors.mix(theme.success, theme.text, 0.25);
}

// Gilt: ribbon, star, and the light of a candle.
function gold(theme) {
    return Colors.mix(theme.yellow, theme.peach, 0.2);
}

function goldDeep(theme) {
    return Colors.mix(gold(theme), theme.crust, 0.4);
}

function glow(theme) {
    return Qt.lighter(theme.yellow, 1.25);
}

// The bulbs of a string of fairy lights, in turn.
function bulbs(theme) {
    return [theme.error, theme.yellow, theme.success, theme.sky, theme.peach];
}
