pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "AppProvider.js" as AppProvider
import "CalculatorProvider.js" as CalculatorProvider
import "BangProvider.js" as BangProvider
import "ThemeProvider.js" as ThemeProvider
import "Shell.js" as Shell

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
    // "theme" or "wall" while browsing with that bang, else "".
    property string browsingThemes: ""
    readonly property string usagePath: ConfigService.dataDir !== ""
        ? ConfigService.dataDir + "/launcher-usage.json"
        : ""
    readonly property var launcherConfig: ConfigService.config && ConfigService.config.launcher
        ? ConfigService.config.launcher
        : ({
            searchUrl: "https://duckduckgo.com/?q={query}",
            bangs: ({})
        })

    function open() {
        root.shown = true;
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
        if (!FeatureSupport.supportsDisplayControl || !DisplayService.canMirror)
            return [];
        return [DisplayService.mirrored
            ? BangProvider.commandResult("mirror", "Stop mirroring", "Extend the displays again", "display", "display monitor screen")
            : BangProvider.commandResult("mirror", "Mirror displays", "Show this display on all of them", "display", "display monitor screen")];
    }

    function rebuild() {
        var trimmed = root.query.trim();
        var wasBrowsing = root.browsingThemes;
        root.browsingThemes = "";
        if (trimmed.indexOf("!") === 0) {
            var themeBang = ThemeProvider.parseBang(trimmed, ThemeService.wallpaperEnabled);
            if (themeBang && themeBang.complete) {
                // Rescan on entering the bang so new themes and wallpapers show up.
                if (wasBrowsing !== themeBang.alias)
                    ThemeService.scan();
                root.browsingThemes = themeBang.alias;
                root.results = themeBang.alias === "theme"
                    ? ThemeProvider.themeResults(ThemeService.themes,
                        ThemeService.wallpaperEnabled ? ThemeService.wallpapers : [],
                        ThemeService.themeId, themeBang.terms, ThemeService.chosen)
                    : ThemeProvider.wallpaperResults(ThemeService.themes, ThemeService.wallpapers,
                        ThemeService.wallpaper, themeBang.terms);
                return;
            }
            var bangs = BangProvider.bangResults(trimmed, root.launcherConfig, root.commandResults());
            root.results = themeBang
                ? themeBang.alias.map(ThemeProvider.suggestion).concat(bangs.filter(function(result) {
                    return result.id.indexOf("bang:passthrough:") !== 0;
                }))
                : bangs;
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
        var extras = ThemeProvider.searchItems(ThemeService.wallpaperEnabled);
        extras = extras.concat(root.commandResults().map(function(command) {
            return { id: command.id, title: command.title, keywords: command.bang + " " + command.keywords, result: command };
        }));
        var apps = AppProvider.search(root.appIndex.concat(AppProvider.buildExtraIndex(extras)), trimmed, root.usage, 100);
        root.results = apps.length === 0 && trimmed !== ""
            ? BangProvider.searchResult("?" + trimmed, root.launcherConfig)
            : apps;
    }

    function recordLaunch(appId) {
        if (!appId)
            return;
        if (!root.usageLoaded) {
            var pending = root.pendingLaunches;
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
        for (var i = 0; i < source.length; i++)
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
        if (result.kind === "calculator") {
            ClipboardService.copyText(payload.text || "");
            return true;
        }
        if (result.kind === "command" && payload.command === "mirror") {
            // Keep or Revert waits in the Displays panel; unanswered, the change reverts.
            DisplayService.toggleMirror();
            return PanelService.open("display");
        }
        if (result.kind === "theme") {
            if (payload.theme !== undefined)
                return ThemeService.setTheme(payload.theme);
            if (payload.shuffle !== undefined)
                return ThemeService.shuffle(payload.shuffle);
            return ThemeService.setWallpaper(payload.path || "");
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
        if (root.browsingThemes === "theme")
            return "No matching themes";
        if (root.browsingThemes === "wall")
            return "No matching wallpapers in " + ThemeService.themesDir;
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
        for (var i = 0; i < pendingIds.length; i++) {
            var id = pendingIds[i];
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
        function onConfigChanged() { root.rebuild(); }
    }

    Connections {
        target: ThemeService
        function onWallpapersChanged() { root.rebuild(); }
        function onFolderThemesChanged() { root.rebuild(); }
        function onThemeIdChanged() { root.rebuild(); }
        function onWallpaperChanged() { root.rebuild(); }
        function onWallpaperEnabledChanged() { root.rebuild(); }
    }
}
