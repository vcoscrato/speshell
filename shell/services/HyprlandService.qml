pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

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
    property string version: ""
    // The main keyboard's layout, as "Portuguese (Brazil)", and how many it switches
    // between.
    property string keyboard: ""
    property string keyboardLayout: ""
    property int keyboardLayouts: 0

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

    // Runs dispatchers in order, each written for the config's syntax, as dispatch()'s.
    function dispatchAll(dispatchers) {
        if (root.running)
            Quickshell.execDetached(["hyprctl", "--batch", dispatchers.map(line => "dispatch " + line).join(" ; ")]);
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

    Process {
        running: root.running
        command: ["hyprctl", "version"]
        stdout: SplitParser {
            onRead: line => {
                const match = String(line || "").match(/^Hyprland\s+(\S+)/);
                if (match && root.version === "")
                    root.version = match[1];
            }
        }
    }

    Process {
        running: root.running
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const main = JSON.parse(text).keyboards.find(keyboard => keyboard.main);
                    if (!main)
                        return;
                    root.keyboard = main.name;
                    root.keyboardLayout = main.active_keymap;
                    root.keyboardLayouts = String(main.layout || "").split(",").length;
                } catch (error) {}
            }
        }
    }

    Connections {
        target: root.running ? Hyprland : null

        function onRawEvent(event) {
            // "keyboard,Layout name": layout names may hold commas.
            if (event.name === "activelayout") {
                const comma = event.data.indexOf(",");
                if (event.data.substring(0, comma) === root.keyboard)
                    root.keyboardLayout = event.data.substring(comma + 1);
            }
            root.event(event.name, event.data);
        }
    }
}
