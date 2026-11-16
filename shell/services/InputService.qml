pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The touchpad, switched on and off through Hyprland, as a laptop's touchpad key does.
// Hyprland doesn't tell whether a device is on, so turning it off notes this Hyprland's
// instance in the runtime folder, where a Relaunch finds it; a new Hyprland starts with
// it on, as its config has it.
Singleton {
    id: root

    readonly property var touchpads: HyprlandService.touchpads
    readonly property bool available: HyprlandService.running && root.touchpads.length > 0
    property bool touchpadEnabled: true
    readonly property string instance: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || ""

    function setTouchpadEnabled(on) {
        if (!root.available)
            return;
        root.touchpadEnabled = !!on;
        const value = root.touchpadEnabled ? "true" : "false";
        for (const name of root.touchpads)
            HyprlandService.configure("hl.device({ name = " + HyprlandService.luaQuote(name) + ", enabled = " + value + " })",
                "device[" + name + "]:enabled", value);
        offFile.setText(root.touchpadEnabled ? "" : root.instance);
    }

    // From a keybinding: switched, and shown in the OSD.
    function setFromKey(on) {
        if (!root.available)
            return;
        root.setTouchpadEnabled(on);
        OsdService.show(root.touchpadEnabled ? "touchpad" : "touchpad-off",
            root.touchpadEnabled ? "Touchpad on" : "Touchpad off");
    }

    FileView {
        id: offFile
        path: root.instance !== "" && Quickshell.env("XDG_RUNTIME_DIR")
            ? Quickshell.env("XDG_RUNTIME_DIR") + "/speshell/touchpad-off"
            : ""
        // Read at once, so a switch right after a Relaunch starts from the real state.
        blockLoading: true
        printErrors: false
        onLoaded: root.touchpadEnabled = offFile.text().trim() !== root.instance
    }
}
