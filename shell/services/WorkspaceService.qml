pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Hyprland's regular workspaces for the bar and its windows for WindowService, and the
// dispatches that show one. Quickshell's own Hyprland models are incomplete under a Lua
// config, so state comes from hyprctl's JSON and refreshes on Hyprland's events.
Singleton {
    id: root

    readonly property bool available: HyprlandService.running
    // Every monitor's workspaces in id order: those with windows and each monitor's
    // active one, as { id, name, monitor, active, occupied, title }, where `title` is
    // that of the workspace's last focused window.
    property var workspaces: []
    // Every mapped window, last focused first, as { address, appClass, title, workspace,
    // workspaceName, special, shown }: `workspace` is its id and `workspaceName` its
    // name, and `shown` whether a special workspace it is on shows.
    property var windows: []
    // The JSON `workspaces` and `windows` were read from, so an unchanged read leaves
    // them alone.
    property string lastRead: ""
    property string lastWindowsRead: ""
    property bool refreshQueued: false

    // Events after which the workspaces may have changed. Window titles change too
    // often to follow; the bar and the launcher refresh when they are about to show.
    readonly property var refreshEvents: [
        "activespecial", "activespecialv2",
        "openwindow", "closewindow", "movewindow", "movewindowv2", "workspace", "workspacev2",
        "createworkspace", "createworkspacev2", "destroyworkspace", "destroyworkspacev2",
        "moveworkspace", "moveworkspacev2", "focusedmon", "focusedmonv2", "activewindowv2",
        "renameworkspace"
    ]

    function refresh() {
        if (!root.available)
            return;
        if (stateProc.running) {
            root.refreshQueued = true;
            return;
        }
        stateProc.running = true;
    }

    function read(monitors, workspaces, clients) {
        const activeIds = {};
        for (const monitor of monitors) {
            if (monitor.activeWorkspace)
                activeIds[monitor.name] = monitor.activeWorkspace.id;
        }

        const byId = {};
        const focusOrder = {};
        const add = (id, name, monitor) => {
            if (byId[id] || id <= 0)
                return;
            byId[id] = {
                id: id,
                name: String(name || id),
                monitor: String(monitor || ""),
                active: activeIds[monitor] === id,
                occupied: false,
                title: ""
            };
            focusOrder[id] = Infinity;
        };
        for (const workspace of workspaces)
            add(workspace.id, workspace.name, workspace.monitor);
        for (const monitor of monitors) {
            if (monitor.activeWorkspace)
                add(monitor.activeWorkspace.id, monitor.activeWorkspace.name, monitor.name);
        }

        // The window with the lowest focus history ID was focused last.
        for (const client of clients) {
            const workspace = client.mapped !== false && client.workspace ? byId[client.workspace.id] : null;
            if (!workspace)
                continue;
            workspace.occupied = true;
            const history = client.focusHistoryID ?? Infinity;
            if (workspace.title === "" || history < focusOrder[workspace.id]) {
                focusOrder[workspace.id] = history;
                workspace.title = String(client.title || client["class"] || "");
            }
        }

        return Object.values(byId)
            .filter(workspace => workspace.occupied || workspace.active)
            .sort((a, b) => a.id - b.id);
    }

    function readWindows(monitors, clients) {
        const shownSpecials = monitors.map(monitor => monitor.specialWorkspace ? monitor.specialWorkspace.name : "");
        return clients
            .filter(client => client.mapped !== false && client.workspace && client.workspace.id !== -1)
            .sort((a, b) => (a.focusHistoryID ?? Infinity) - (b.focusHistoryID ?? Infinity))
            .map(client => {
                const name = String(client.workspace.name || client.workspace.id);
                const special = name.indexOf("special:") === 0;
                return {
                    address: String(client.address || ""),
                    appClass: String(client["class"] || client.initialClass || ""),
                    title: String(client.title || ""),
                    workspace: client.workspace.id,
                    workspaceName: name,
                    special: special,
                    shown: special && shownSpecials.indexOf(name) >= 0
                };
            });
    }

    function apply(text) {
        const parts = String(text || "").split("\u001e");
        try {
            const monitors = JSON.parse(parts[0]);
            const clients = JSON.parse(parts[2]);
            const workspaces = root.read(monitors, JSON.parse(parts[1]), clients);
            const read = JSON.stringify(workspaces);
            if (read !== root.lastRead) {
                root.lastRead = read;
                root.workspaces = workspaces;
            }
            const windows = root.readWindows(monitors, clients);
            const windowsRead = JSON.stringify(windows);
            if (windowsRead !== root.lastWindowsRead) {
                root.lastWindowsRead = windowsRead;
                root.windows = windows;
            }
        } catch (error) {
            console.warn("[Speshell] Failed to read Hyprland workspaces:", error);
        }
    }

    function focus(id) {
        HyprlandService.dispatch("hl.dsp.focus({ workspace = " + Number(id) + " })", "workspace " + Number(id));
    }

    // Focuses `window`, of `windows`, showing the special workspace it is on first.
    function focusWindow(window) {
        const address = "address:" + window.address;
        const focus = [HyprlandService.usingLua
            ? "hl.dsp.focus({ window = " + HyprlandService.luaQuote(address) + " })"
            : "focuswindow " + address];
        if (window.special && !window.shown) {
            const name = window.workspaceName.substring("special:".length);
            focus.unshift(HyprlandService.usingLua
                ? "hl.dsp.workspace.toggle_special(" + HyprlandService.luaQuote(name) + ")"
                : "togglespecialworkspace " + name);
        }
        HyprlandService.dispatchAll(focus);
    }

    Component.onCompleted: root.refresh()

    Timer {
        id: refreshTimer
        interval: 60
        onTriggered: root.refresh()
    }

    Process {
        id: stateProc
        command: ["sh", "-c", "hyprctl -j monitors; printf '\\036'; hyprctl -j workspaces; printf '\\036'; hyprctl -j clients"]
        stdout: StdioCollector {
            onStreamFinished: root.apply(text)
        }
        onExited: {
            if (root.refreshQueued) {
                root.refreshQueued = false;
                refreshTimer.restart();
            }
        }
    }

    Connections {
        target: HyprlandService

        function onEvent(name) {
            if (root.refreshEvents.indexOf(name) >= 0)
                refreshTimer.restart();
        }
    }
}
