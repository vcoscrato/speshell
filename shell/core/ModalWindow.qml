// Quickshell's type info marks PanelWindow uncreatable, though QML creates it.
// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services

// A window over the whole of `targetScreen`, above everything: the launcher, the theme
// gallery, the polkit prompt, the config error, the login screen. While `opened`, it takes
// the keyboard and the pointer; mapped but not opened, as while an exit plays, clicks go
// through it. With a `focusTarget`, the keys go there from the moment it maps, and it
// holds Hyprland's focus while it takes the keyboard, so they stay. `behind`, it steps
// back under the windows, as the config error does while its editor is open, and takes
// the keyboard only when clicked.
PanelWindow {
    id: root

    property var targetScreen: null
    property bool opened: true
    property bool behind: false
    // An Item, or a Field, whose focusInput() puts the keys in its input; untyped, so
    // that can be asked.
    property var focusTarget: null
    property bool takesKeyboard: root.visible && root.opened && !root.behind

    // Gives the target the window's focus. The window behind a layer surface is made anew
    // each time it maps, so it is given as each one connects, before the compositor's first
    // key can arrive, and again when an exit is called back while still mapped.
    function focusIn() {
        if (!root.focusTarget || !root.opened)
            return;
        if (typeof root.focusTarget.focusInput === "function")
            root.focusTarget.focusInput();
        else
            root.focusTarget.forceActiveFocus();
    }

    screen: root.targetScreen
    color: "transparent"
    focusable: true
    aboveWindows: !root.behind
    exclusionMode: ExclusionMode.Ignore
    mask: root.opened ? null : passThrough

    WlrLayershell.layer: root.behind ? WlrLayer.Bottom : WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.takesKeyboard ? WlrKeyboardFocus.Exclusive
        : root.behind ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    onWindowConnected: root.focusIn()
    onOpenedChanged: if (root.backingWindowVisible) root.focusIn()
    onFocusTargetChanged: if (root.backingWindowVisible) root.focusIn()

    Region { id: passThrough }

    HyprlandFocusGrab {
        active: !!root.focusTarget && root.takesKeyboard && root.backingWindowVisible && HyprlandService.running
        windows: [root]
    }
}
