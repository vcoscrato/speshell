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
    readonly property int keyboardLayouts: root.keyboardLayoutList.length
    // The layouts it switches between, as { code: "BR", name: "Portuguese (Brazil)" },
    // and the active one's index.
    property var keyboardLayoutList: []
    property int keyboardLayoutIndex: -1
    // xkb's names for layouts ("br") and their variants ("br:nodeadkeys").
    property var xkbNames: ({})

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

    // Switches every keyboard to the layout at `index` of keyboardLayoutList.
    function switchKeyboardLayout(index) {
        if (root.running)
            Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", String(index)]);
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

    // Read again on each layout switch, as the main keyboard may change with it, and
    // on a config reload; a switch on every keyboard reads once.
    Timer {
        id: devicesRefresh
        interval: 50
        onTriggered: devices.running = true
    }

    Process {
        id: devices
        running: root.running
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const main = JSON.parse(text).keyboards.find(keyboard => keyboard.main);
                    if (!main)
                        return;
                    const layouts = String(main.layout || "").split(",");
                    const variants = String(main.variant || "").split(",");
                    root.keyboard = main.name;
                    root.keyboardLayout = main.active_keymap;
                    root.keyboardLayoutIndex = main.active_layout_index;
                    root.keyboardLayoutList = layouts.map((layout, i) => {
                        const variant = variants[i] || "";
                        return {
                            code: layout.toUpperCase(),
                            name: i === main.active_layout_index ? main.active_keymap
                                : root.xkbNames[variant !== "" ? layout + ":" + variant : layout]
                                    || root.xkbNames[layout] || layout.toUpperCase()
                        };
                    });
                } catch (error) {}
            }
        }
    }

    // `! layout` lines read "  br  Portuguese (Brazil)", and `! variant` lines
    // "  nodeadkeys  br: Portuguese (Brazil, no dead keys)".
    FileView {
        path: root.running ? "/usr/share/X11/xkb/rules/evdev.lst" : ""
        printErrors: false
        onLoaded: {
            const names = {};
            let section = "";
            for (const line of text().split("\n")) {
                if (line.startsWith("! ")) {
                    section = line.substring(2).trim();
                    continue;
                }
                const match = line.match(/^\s+(\S+)\s+(.+)$/);
                if (!match)
                    continue;
                if (section === "layout")
                    names[match[1]] = match[2];
                else if (section === "variant") {
                    const colon = match[2].indexOf(": ");
                    if (colon > 0)
                        names[match[2].substring(0, colon) + ":" + match[1]] = match[2].substring(colon + 2);
                }
            }
            root.xkbNames = names;
            devicesRefresh.restart();
        }
    }

    Connections {
        target: root.running ? Hyprland : null

        function onRawEvent(event) {
            if (event.name === "activelayout" || event.name === "configreloaded")
                devicesRefresh.restart();
            root.event(event.name, event.data);
        }
    }
}
