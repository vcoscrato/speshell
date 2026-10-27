.pragma library
.import "common/Colors.js" as Colors

// Earth's rock: one of a theme's neutral colors (`name`, as Theme.qml names it) warmed
// toward its peach by `warmth`; `fallback` before a theme arrives.
function tone(theme, name, warmth, fallback) {
    return theme ? Colors.mix(theme[name], theme.peach, warmth) : fallback;
}
