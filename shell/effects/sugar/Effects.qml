import QtQuick

// Sugar effects: a launcher piped round with frosting and eaten away in bites,
// wallpapers glazed over, sliders piped with a bag and scraped with a spatula, and
// switches that glaze an éclair.
// A theme picks them with `effects = sugar` in its theme.ini.
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
