pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "AppProvider.js" as AppProvider
import "CalculatorProvider.js" as CalculatorProvider
import "BangProvider.js" as BangProvider
import "Shell.js" as Shell

// The launcher's state and results: apps, open windows and apps hidden in the tray, the
// calculator, bangs, web searches, its own commands (the theme gallery, mirroring), and
// what activating each does. Launch counts order the apps.
Singleton {
    id: root

    // Whether the launcher shows; the launcher window follows it.
    property bool shown: false
    property string query: ""
    property var results: []
    property var appIndex: []
    property var usage: ({})
    property bool saveQueued: false
    property bool usageLoaded: false
    property bool savingUsage: false
    property var pendingLaunches: ({})
    property string activationError: ""
    readonly property string usagePath: ConfigService.dataDir !== ""
        ? ConfigService.dataDir + "/launcher-usage.json"
        : ""
    readonly property var launcherConfig: ConfigService.settings.launcher

    function open() {
        root.shown = true;
    }

    // Open windows and apps hidden in the tray, as buildExtraIndex() items, each above
    // its app; windows last focused first.
    function windowItems() {
        const items = WindowService.windows.map((window, order) => {
            const name = window.entry ? window.entry.name : window.appClass;
            const where = window.special ? "Scratchpad" : "Workspace " + window.workspaceName;
            return {
                id: window.entry ? window.entry.id : "window:" + window.appClass,
                title: name,
                detail: window.title,
                keywords: window.appClass,
                bonus: 1 + 1 / (order + 1),
                result: {
                    id: "window:" + window.address,
                    kind: "window",
                    title: window.title || name,
                    subtitle: window.title !== "" ? name + "  ·  " + where : where,
                    iconName: "apps",
                    iconSource: window.entry ? window.entry.icon : window.appClass,
                    badge: "WINDOW",
                    activatable: true,
                    payload: { window: window }
                }
            };
        });
        return items.concat(WindowService.hiddenApps.map(entry => ({
            id: entry.id,
            title: entry.name,
            detail: "",
            bonus: 1,
            result: {
                id: "hidden:" + entry.id,
                kind: "window",
                title: entry.name,
                subtitle: "Hidden in the tray",
                iconName: "apps",
                iconSource: entry.icon,
                badge: "WINDOW",
                activatable: true,
                payload: { entry: entry }
            }
        })));
    }

    function close() {
        root.shown = false;
    }

    function toggle() {
        root.shown = !root.shown;
    }

    function setQuery(value) {
        var next = String(value || "");
        if (root.query === next)
            return;
        root.query = next;
        root.activationError = "";
        root.rebuild();
    }

    function rebuildAppIndex() {
        var entries = DesktopEntries.applications && DesktopEntries.applications.values
            ? DesktopEntries.applications.values
            : [];
        root.appIndex = AppProvider.buildIndex(entries);
        root.rebuild();
    }

    function calculatorResults(calculation) {
        if (!calculation.candidate)
            return [];
        if (!calculation.ok) {
            return [{
                id: "calculator:error",
                kind: "error",
                title: "Invalid expression",
                subtitle: calculation.error,
                iconName: "alert",
                iconSource: "",
                badge: "CALC",
                activatable: false,
                payload: ({})
            }];
        }
        return [{
            id: "calculator:" + calculation.expression,
            kind: "calculator",
            title: calculation.result,
            subtitle: calculation.expression + "  ·  Enter to copy",
            iconName: "calculator",
            iconSource: "",
            badge: "CALC",
            activatable: true,
            payload: { text: calculation.result }
        }];
    }

    // The launcher's own actions that apply right now.
    function commandResults() {
        var commands = [BangProvider.commandResult("theme", "Themes", "Pick a theme, then its wallpaper", "palette",
            "wallpaper background color scheme palette appearance speshell")];
        // Only when there is another wallpaper to pick.
        if (ThemeService.wallpaperEnabled
                && ThemeService.wallpapers.filter(wallpaper => wallpaper.theme === ThemeService.themeId).length > 1)
            commands.push(BangProvider.commandResult("wallpaper", "Wallpapers", "Pick another wallpaper of " + ThemeService.theme.name,
                "photo", "background picture image appearance"));
        if (!FeatureSupport.supportsDisplayControl || !DisplayService.canMirror)
            return commands;
        return commands.concat([DisplayService.mirrored
            ? BangProvider.commandResult("mirror", "Stop mirroring", "Extend the displays again", "display", "display monitor screen")
            : BangProvider.commandResult("mirror", "Mirror displays", "Show this display on all of them", "display", "display monitor screen")]);
    }

    function rebuild() {
        var trimmed = root.query.trim();
        if (trimmed.indexOf("!") === 0) {
            root.results = BangProvider.bangResults(trimmed, root.launcherConfig, root.commandResults());
            return;
        }
        if (trimmed.indexOf("?") === 0) {
            root.results = BangProvider.searchResult(trimmed, root.launcherConfig);
            return;
        }

        var calculation = CalculatorProvider.evaluate(trimmed);
        if (calculation.candidate) {
            root.results = root.calculatorResults(calculation);
            return;
        }
        var extras = root.commandResults().map(function(command) {
            return { id: command.id, title: command.title, keywords: command.bang + " " + command.keywords, result: command };
        });
        var apps = AppProvider.search(root.appIndex.concat(AppProvider.buildExtraIndex(extras.concat(root.windowItems()))),
            trimmed, root.usage, 100);
        root.results = apps.length === 0 && trimmed !== ""
            ? BangProvider.searchResult("?" + trimmed, root.launcherConfig)
            : apps;
    }

    function recordLaunch(appId) {
        if (!appId)
            return;
        if (!root.usageLoaded) {
            const pending = root.pendingLaunches;
            pending[appId] = (pending[appId] || 0) + 1;
            root.pendingLaunches = pending;
        }

        var next = Object.assign({}, root.usage);
        next[appId] = { count: AppProvider.usageCount(next, appId) + 1, lastUsed: new Date().toISOString() };
        root.usage = next;
        root.saveUsage();
    }

    // DesktopEntry.execute() ignores Terminal=true, so wrap those commands.
    function launchEntry(entry) {
        var command = [];
        var source = entry.command || [];
        for (let i = 0; i < source.length; i++)
            command.push(String(source[i]));
        if (!entry.runInTerminal || command.length === 0) {
            entry.execute();
            return;
        }
        var context = { command: Shell.terminalCommand(command) };
        if (entry.workingDirectory)
            context.workingDirectory = entry.workingDirectory;
        Quickshell.execDetached(context);
    }

    function complete(result) {
        if (result && result.completion)
            root.setQuery(result.completion);
    }

    function activate(result) {
        root.activationError = "";
        if (!result || result.activatable === false)
            return false;
        if (result.completeOnActivate) {
            root.complete(result);
            return false;
        }
        var payload = result.payload || ({});
        if (result.kind === "app" && payload.entry) {
            root.recordLaunch(payload.appId);
            root.launchEntry(payload.entry);
            return true;
        }
        if (result.kind === "window") {
            if (payload.window)
                WindowService.focus(payload.window);
            else
                WindowService.show(payload.entry, false);
            return true;
        }
        if (result.kind === "calculator") {
            ClipboardService.copyText(payload.text || "");
            return true;
        }
        if (result.kind === "command" && payload.command === "mirror") {
            DisplayService.toggleMirror();
            return true;
        }
        if (result.kind === "command" && payload.command === "theme") {
            ThemeService.openGallery();
            return true;
        }
        if (result.kind === "command" && payload.command === "wallpaper") {
            ThemeService.openGallery("wallpapers");
            return true;
        }
        if (result.kind === "web" && payload.url) {
            Qt.openUrlExternally(payload.url);
            return true;
        }
        root.activationError = "This launcher result cannot be activated.";
        return false;
    }

    function emptyMessage() {
        var trimmed = root.query.trim();
        if (trimmed.indexOf("?") === 0)
            return "Type a web search after ?";
        if (trimmed.indexOf("!") === 0)
            return "No matching commands";
        return "No applications found";
    }

    function readUsage() {
        if (root.usagePath === "" || root.usageLoaded)
            return;
        usageFile.reload();
    }

    function saveUsage() {
        if (root.usagePath === "")
            return;
        if (!root.usageLoaded || root.savingUsage) {
            root.saveQueued = true;
            return;
        }
        root.savingUsage = true;
        usageFile.setText(JSON.stringify(root.usage || ({})));
    }

    function finishUsageLoad(text) {
        if (root.usageLoaded)
            return;
        var parsed = ({});
        try {
            parsed = JSON.parse(text || "{}");
        } catch (usageError) {
            parsed = ({});
        }
        var loadedUsage = parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : ({});
        var pendingIds = Object.keys(root.pendingLaunches);
        for (let i = 0; i < pendingIds.length; i++) {
            const id = pendingIds[i];
            loadedUsage[id] = {
                count: AppProvider.usageCount(loadedUsage, id) + root.pendingLaunches[id],
                lastUsed: new Date().toISOString()
            };
        }
        root.pendingLaunches = ({});
        root.usage = loadedUsage;
        root.usageLoaded = true;
        if (root.saveQueued) {
            root.saveQueued = false;
            root.saveUsage();
        }
    }

    FileView {
        id: usageFile
        path: root.usagePath
        atomicWrites: true
        printErrors: false
        onLoaded: root.finishUsageLoad(usageFile.text())
        onLoadFailed: root.finishUsageLoad("{}")
        onSaved: {
            root.savingUsage = false;
            if (root.saveQueued) {
                root.saveQueued = false;
                root.saveUsage();
            }
        }
        onSaveFailed: root.savingUsage = false
    }

    Component.onCompleted: {
        root.readUsage();
        root.rebuildAppIndex();
    }

    onUsagePathChanged: {
        root.usageLoaded = false;
        root.readUsage();
    }
    onUsageChanged: root.rebuild()
    // Titles aren't followed as they change, so they are read again for each opening.
    onShownChanged: if (root.shown) WorkspaceService.refresh()

    Connections {
        target: WindowService
        function onWindowsChanged() { if (root.shown) root.rebuild(); }
        function onHiddenAppsChanged() { if (root.shown) root.rebuild(); }
    }

    Connections {
        target: ThemeService
        function onWallpapersChanged() { root.rebuild(); }
        function onThemeIdChanged() { root.rebuild(); }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() { root.rebuildAppIndex(); }
    }

    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { root.rebuildAppIndex(); }
    }

    Connections {
        target: ConfigService
        function onSettingsChanged() { root.rebuild(); }
    }
}
