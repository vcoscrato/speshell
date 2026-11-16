import QtQuick
import Quickshell

// Hosts Speshell's own WallpaperView (from SPESHELL_DIR), shows WALL_A, and switches to
// WALL_B with the effects' wallpaper transition at SWITCH_AT seconds, and back to WALL_A
// at SWITCH_AGAIN_AT, if given, to see a transition cut short.
EffectScene {
    id: root
    readonly property real switchAt: Number(Quickshell.env("SWITCH_AT") || 0.3)
    readonly property real switchAgainAt: Number(Quickshell.env("SWITCH_AGAIN_AT") || 0)
    property bool switchedBack: false

    property var view: {
        const component = Qt.createComponent("file://" + Quickshell.env("SPESHELL_DIR") + "/core/WallpaperView.qml");
        if (component.status !== Component.Ready) {
            console.error(component.errorString());
            return null;
        }
        return component.createObject(root, { width: root.width, height: root.height, path: Quickshell.env("WALL_A"),
                                              timeScale: Number(Quickshell.env("SPEED") || 1), theme: root.swatch });
    }

    onPreviewTimeChanged: {
        if (view && !root.switchedBack && previewTime >= switchAt && view.path === Quickshell.env("WALL_A")) {
            view.transition = effects ? effects.wallpaperTransition : null;
            view.path = Quickshell.env("WALL_B");
        } else if (view && root.switchAgainAt > 0 && !root.switchedBack && previewTime >= root.switchAgainAt) {
            root.switchedBack = true;
            view.path = Quickshell.env("WALL_A");
        }
    }

    property bool running: false
    Connections {
        target: root.view
        function onPhaseChanged() {
            const running = root.view.phase === "running" || root.view.phase === "capturing";
            if (running !== root.running)
                console.log("wallpaper transition", running ? "started" : "finished", "at", root.previewTime.toFixed(2));
            root.running = running;
        }
    }
}
