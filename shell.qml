//@ pragma UseQApplication
//@ pragma AppId speshell
pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import qs.services
import qs.theme
import qs.core

ShellRoot {
    id: root

    Binding {
        target: Theme
        property: "textScale"
        value: ConfigService.settings.appearance.textScale
    }

    Binding {
        target: Theme
        property: "paletteOverride"
        value: ThemeService.colors
    }

    // Saver keeps the interface still.
    Binding {
        target: Theme
        property: "motion"
        value: PowerService.mode !== "saver"
    }

    LazyLoader {
        active: ConfigService.valid

        component: Runtime {}
    }

    ConfigErrorWindow {
        active: ConfigService.invalid
    }

    Component.onCompleted: ConfigService.load()
}
