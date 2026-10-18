import QtQuick

// Air effects: a launcher that a whirlpool of wind draws in out of a vortex, and
// wallpapers blown away by the next.
// A theme picks them with `effects = air` in its theme.ini.
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

    readonly property Component button: Component {
        Button {}
    }
}
