import QtQuick
import qs.services

// Speshell's default wallpaper, for themes without one: the mark on the theme's
// darkest color. Its colors are the active theme's unless given, as for a preview.
Rectangle {
    id: root

    property color crust: Theme.crust
    property color surface: Theme.surface2
    property color accent: Theme.accent

    color: root.crust

    SpeshellMark {
        anchors.centerIn: parent
        size: 29 * Math.max(1, Math.round(root.height * 0.16 / 29))
        leftColor: root.surface
        // Opaque, so the overlapping strokes do not show their seams.
        rightColor: Qt.tint(root.crust, Theme.alpha(root.accent, 0.6))
    }
}
