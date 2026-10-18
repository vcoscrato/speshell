import QtQuick

// Relâmpago effects: a launcher that races in and skids to a stop, and wallpapers
// split apart by a lightning strike.
// A theme picks them with `effects = relampago` in its theme.ini.
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
