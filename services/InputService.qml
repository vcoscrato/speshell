pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The touchpad, switched on and off through Hyprland, as a laptop's touchpad key
// does; on again at each start, as Hyprland's config has it.
Singleton {
    id: root

    property var touchpads: []
    readonly property bool available: HyprlandService.running && root.touchpads.length > 0
    property bool touchpadEnabled: true

    function setTouchpadEnabled(on) {
        if (!root.available)
            return;
        root.touchpadEnabled = !!on;
        const value = root.touchpadEnabled ? "true" : "false";
        for (const name of root.touchpads) {
            if (HyprlandService.usingLua)
                Quickshell.execDetached(["hyprctl", "eval",
                    "hl.device({ name = " + HyprlandService.luaQuote(name) + ", enabled = " + value + " })"]);
            else
                Quickshell.execDetached(["hyprctl", "keyword", "device[" + name + "]:enabled", value]);
        }
    }

    // From a keybinding: switched, and shown in the OSD.
    function setFromKey(on) {
        if (!root.available)
            return;
        root.setTouchpadEnabled(on);
        OsdService.show(root.touchpadEnabled ? "touchpad" : "touchpad-off",
            root.touchpadEnabled ? "Touchpad on" : "Touchpad off", "", -1);
    }

    Process {
        running: HyprlandService.running
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const mice = JSON.parse(text || "{}").mice || [];
                    root.touchpads = mice.map(mouse => String(mouse.name || ""))
                        .filter(name => /touchpad/i.test(name));
                } catch (error) {
                    console.warn("[Speshell] Could not read Hyprland's devices:", error);
                }
            }
        }
    }
}
