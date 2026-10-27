import QtQuick

// Earth effects: a launcher that rises out of the ground as a slab, and
// wallpapers that crack and crumble away.
// A theme picks them with `effects = earth` in its theme.ini.
QtObject {
    readonly property int apiVersion: 1

    readonly property Component launcherTransition: Component {
        LauncherTransition {}
    }

    readonly property Component wallpaperTransition: Component {
        WallpaperTransition {}
    }

    readonly property Component backdrop: Component {
        Backdrop {}
    }

    readonly property Component interactions: Component {
        Interactions {}
    }

    readonly property Component knob: Component {
        Knob {}
    }

    readonly property Component clock: Component {
        Clock {}
    }
}
