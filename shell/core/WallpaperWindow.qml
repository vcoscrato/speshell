pragma ComponentBehavior: Bound
// Quickshell's type info marks PanelWindow uncreatable, though QML creates it.
// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

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

    WallpaperView {
        id: view
        anchors.fill: parent
        path: ThemeService.shownWallpaper
        theme: Theme
        fadeDuration: Theme.animDurationSlow
        transition: EffectsService.wallpaperTransition
        timeScale: EffectsService.wallpaperSpeed
        frameRate: EffectsService.frameRate
        pixelRatio: root.devicePixelRatio

        onLoadingChanged: ThemeService.wallpapersLoading += view.loading ? 1 : -1
        Component.onDestruction: if (view.loading) ThemeService.wallpapersLoading--

        // The default wallpaper, until the theme's arrives and for themes without one.
        DefaultWallpaper {
            anchors.fill: parent
        }
    }

    Connections {
        target: ThemeService

        function onPlaced(screen) {
            if (screen === root.modelData)
                view.place();
        }
    }
}
