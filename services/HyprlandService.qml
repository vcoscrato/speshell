pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Speshell's integration with Hyprland: whether it runs this session, its focused
// monitor, its events, and its dispatchers. Everything Hyprland-only goes through
// here, so on another compositor the rest of the shell runs without it.
Singleton {
    id: root

    readonly property bool running: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "") !== ""
    // Whether Hyprland reads a Lua config; its dispatchers then take Lua.
    readonly property bool usingLua: root.running && Hyprland.usingLua
    readonly property string focusedMonitor: root.running && Hyprland.focusedMonitor
        ? Hyprland.focusedMonitor.name
        : ""

    // Hyprland's socket events, as `name>>data` lines split at the `>>`.
    signal event(string name, string data)

    // The focused monitor's screen; the first screen where Hyprland doesn't run.
    function focusedScreen() {
        const screens = Quickshell.screens;
        return screens.find(screen => screen.name === root.focusedMonitor) || screens[0] || null;
    }

    // Runs a dispatcher, written for each config syntax: `lua` as a Lua expression
    // and `legacy` as `dispatcher args`.
    function dispatch(lua, legacy) {
        if (root.running)
            Quickshell.execDetached(["hyprctl", "dispatch", root.usingLua ? lua : legacy]);
    }

    // Has Quickshell's monitor model follow a change Hyprland made.
    function refreshMonitors() {
        if (root.running)
            Hyprland.refreshMonitors();
    }

    // A Lua string literal, for Lua dispatchers and `hyprctl eval`.
    function luaQuote(value) {
        return "\"" + String(value || "")
            .replace(/\\/g, "\\\\")
            .replace(/"/g, "\\\"")
            .replace(/\r/g, "\\r")
            .replace(/\n/g, "\\n") + "\"";
    }

    Connections {
        target: root.running ? Hyprland : null

        function onRawEvent(event) {
            root.event(event.name, event.data);
        }
    }
}
