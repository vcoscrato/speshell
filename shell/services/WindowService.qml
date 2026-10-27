pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// Apps' windows, matched to their desktop entries: the open ones to switch to, and the
// apps hidden in the tray with none, such as Steam or Discord closed to it. show()
// brings an app forward wherever it is; the launcher and the notifications use it.
Singleton {
    id: root

    // WorkspaceService's windows, each with its app's desktop entry, or null.
    readonly property var windows: WorkspaceService.windows.map(window => Object.assign({
        entry: root.entryFor(window.appClass)
    }, window))
    // The desktop entries of apps running in the tray with no window. Electron apps
    // name their tray item "<app>_status_icon_<n>".
    readonly property var hiddenApps: {
        const hidden = [];
        for (const item of root.trayItems(SystemTray)) {
            const entry = root.entryFor(String(item.id || "").replace(/_status_icon_\d+$/, ""))
                ?? root.entryFor(item.title);
            if (entry && hidden.indexOf(entry) < 0 && root.windowsOf(entry).length === 0)
                hidden.push(entry);
        }
        return hidden;
    }
    // The app a notification's action may be showing, whose window show() waits for.
    property var awaitedEntry: null

    // Quickshell's type info leaves the tray's model untyped.
    function trayItems(tray) {
        return tray.items.values;
    }

    // The desktop entry with this id, window class, or name.
    function entryFor(name) {
        const id = String(name || "").replace(/\.desktop$/, "");
        return id !== "" ? DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id) : null;
    }

    function windowsOf(entry) {
        return root.windows.filter(window => window.entry === entry);
    }

    function focus(window) {
        WorkspaceService.focusWindow(window);
    }

    // Focuses the app's last focused window, or launches it, which an app hidden in the
    // tray answers by showing its window. `awaitWindow`, after a notification's action,
    // which may show the window itself, gives the app a moment first; it then only
    // launches an app hidden in the tray.
    function show(entry, awaitWindow) {
        if (!entry)
            return;
        const window = root.windowsOf(entry)[0];
        if (window) {
            root.focus(window);
        } else if (awaitWindow) {
            root.awaitedEntry = entry;
            awaitTimer.restart();
        } else {
            LauncherService.launchEntry(entry);
        }
    }

    onWindowsChanged: {
        const window = root.awaitedEntry ? root.windowsOf(root.awaitedEntry)[0] : null;
        if (window) {
            awaitTimer.stop();
            root.awaitedEntry = null;
            root.focus(window);
        }
    }

    Timer {
        id: awaitTimer
        interval: 1500
        onTriggered: {
            const entry = root.awaitedEntry;
            root.awaitedEntry = null;
            if (root.hiddenApps.indexOf(entry) >= 0)
                LauncherService.launchEntry(entry);
        }
    }
}
