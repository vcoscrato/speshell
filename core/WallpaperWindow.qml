pragma ComponentBehavior: Bound
// Quickshell's type info marks PanelWindow uncreatable, though QML creates it.
// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services
import qs.theme

// The wallpaper on one screen's background layer.
PanelWindow {
    id: root

    required property var modelData

    screen: root.modelData
    color: Theme.crust
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "speshell-wallpaper"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // The default wallpaper, under any theme wallpaper: the Speshell mark on the
    // theme's darkest color.
    SpeshellMark {
        anchors.centerIn: parent
        size: 29 * Math.max(2, Math.round(root.height * 0.16 / 29))
        leftColor: Theme.surface2
        // Opaque, so the overlapping strokes do not show their seams.
        rightColor: Qt.tint(Theme.crust, Theme.alpha(Theme.accent, 0.6))
    }

    WallpaperView {
        anchors.fill: parent
        path: ThemeService.shownWallpaper
        theme: Theme
        fadeDuration: Theme.animDurationSlow
        transition: EffectsService.wallpaperTransition
        timeScale: EffectsService.wallpaperSpeed
        frameRate: EffectsService.frameRate
        pixelRatio: root.devicePixelRatio
    }
}
