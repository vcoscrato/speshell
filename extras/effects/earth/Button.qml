import QtQuick
import "common"

// Earth's button face: a slab of cut jade in the accent, its facets lit from above.
// Hovered, the light swings across and the facets turned to it glint.
ButtonFace {
    property color cJade: theme ? theme.accent : "#5fa57a"
    property color cGlint: theme ? theme.text : "#e9e6d3"
    property color cShade: theme ? theme.crust : "#0d0f0a"
    fragmentShader: Qt.resolvedUrl("qsb/Button.qsb")
}
