import QtQuick

// Natal effects: a launcher that thaws in through frost, is hung with fairy lights
// and drifted with snow while open, and is wrapped as a present to close; wallpapers
// frosted over and thawed; baubles and fairy lights on the sliders, and snowflakes
// where you click.
// A theme picks them with `effects = natal` in its theme.ini.
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
