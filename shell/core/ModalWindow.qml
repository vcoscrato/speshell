// Quickshell's type info marks PanelWindow uncreatable, though QML creates it.
// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services

// A window over the whole of `targetScreen`, above everything, that takes the keyboard
// while `takesKeyboard` and, while `focusGrabActive`, holds Hyprland's focus: the
// launcher, the theme gallery, the polkit prompt, the config error, the login screen.
PanelWindow {
    id: root

    property var targetScreen: null
    property bool takesKeyboard: root.visible
    property bool focusGrabActive: false

    screen: root.targetScreen
    color: "transparent"
    focusable: true
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.takesKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    HyprlandFocusGrab {
        active: root.focusGrabActive && HyprlandService.running
        windows: [root]
    }
}
