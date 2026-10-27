//@ pragma UseQApplication
//@ pragma AppId speshell
pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import qs.services
import qs.core

ShellRoot {
    id: root

    // Services that act on their own, created first rather than when the bar first
    // reads them: idling, the battery's warnings, the lid, the radios and touchpad that
    // keys switch, and the night light. They run with the defaults
    // while config.ini is invalid, so the session still locks.
    readonly property var autonomousServices: [IdleService, BatteryService, BrightnessService, DisplayService,
        RadioService, InputService, NightLightService]

    Binding {
        target: Theme
        property: "textScale"
        value: ConfigService.settings.appearance.textScale
    }

    Binding {
        target: Theme
        property: "paletteOverride"
        value: ThemeService.shownColors
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

    // The session lock and the polkit agent work while config.ini is invalid, too.
    LockScreen {}

    AuthPrompt {}

    Component.onCompleted: ConfigService.load()
}
