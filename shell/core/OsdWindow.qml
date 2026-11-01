pragma ComponentBehavior: Bound
// Quickshell's type info marks PanelWindow uncreatable, though QML creates it.
// qmllint disable uncreatable-type
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services

// A transient card over everything on the focused screen that never takes focus:
// present() pops `card` in, dismiss() fades it out and then unmaps the window.
PanelWindow {
    id: root

    required property Item card
    property bool shown: false
    property var targetScreen: null

    signal hidden()

    function present() {
        if (exitAnimation.running) {
            exitAnimation.stop();
            root.card.opacity = 1;
        }
        if (root.shown)
            return;
        root.targetScreen = HyprlandService.focusedScreen();
        root.shown = true;
        entrance.play();
    }

    function dismiss() {
        if (root.shown)
            exitAnimation.restart();
    }

    screen: root.targetScreen
    visible: root.shown && root.targetScreen !== null
    color: "transparent"
    focusable: false
    aboveWindows: true
    // Clear of the bar, which reserves its edge.
    exclusionMode: ExclusionMode.Normal

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    PopIn {
        id: entrance
        card: root.card
    }

    NumberAnimation {
        id: exitAnimation
        target: root.card
        property: "opacity"
        to: 0
        duration: Theme.motion ? 140 : 0
        easing.type: Easing.InCubic
        // Also stopped, short of the end, when present() takes the card back.
        onStopped: {
            if (root.card.opacity <= 0) {
                root.shown = false;
                root.hidden();
            }
        }
    }
}
