.pragma library
.import "common/Colors.js" as Colors

// Earth's rock: one of a theme's neutral colors (`name`, as Theme.qml names it) warmed
// toward its peach by `warmth`.
function tone(theme, name, warmth) {
    return Colors.mix(theme[name], theme.peach, warmth);
}
