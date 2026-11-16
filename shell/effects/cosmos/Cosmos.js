.pragma library
.import "common/Colors.js" as Colors

// Cosmos's colors, from a theme (`theme` as Theme.qml names it).

// A star's white-hot core, brighter than any theme color.
function hot(theme) {
    return Qt.lighter(Colors.mix(theme.text, theme.yellow, 0.15), 1.2);
}
