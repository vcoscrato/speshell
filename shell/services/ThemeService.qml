pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "ThemeProvider.js" as ThemeProvider

// The active theme and its wallpaper. Themes are folders holding a theme.ini and
// wallpapers, shipped under themes/ and added under <configDir>/themes;
// picking a wallpaper applies its folder's theme, and a theme comes back with the
// wallpaper last set for it. See README "Themes".
Singleton {
    id: root

    readonly property string shippedThemesDir: Quickshell.shellDir + "/themes"
    readonly property string shippedEffectsDir: Quickshell.shellDir + "/effects"
    readonly property string themesDir: ConfigService.configDir !== ""
        ? ConfigService.configDir + "/themes"
        : ""
    readonly property string userEffectsDir: ConfigService.dataDir !== ""
        ? ConfigService.dataDir + "/effects"
        : ""
    // User folders come last, so they override shipped ones of the same name.
    readonly property var themesDirs: [root.shippedThemesDir, root.themesDir]
    readonly property string statePath: ConfigService.dataDir !== ""
        ? ConfigService.dataDir + "/theme.json"
        : ""

    property var folderThemes: []
    property var wallpapers: []
    property bool scanned: false
    // The user folders the last finished scan covered; until they are the current
    // ones, a scan from before the config loaded may be missing the user's themes.
    property string scannedDirs: ""
    readonly property string scanDirs: root.themesDir + "\n" + root.userEffectsDir
    readonly property bool scanning: scanProc.running
    property bool stateLoaded: false
    property bool saving: false
    property bool saveQueued: false
    property string reported: ""

    property string themeId: ThemeProvider.defaultTheme
    property string wallpaper: ""
    // Theme id -> the wallpaper last set for it.
    property var chosen: ({})
    // The last applied theme, saved with the selection so startup can apply it
    // before the scan finishes.
    property var snapshot: null

    readonly property var themes: ThemeProvider.allThemes(root.folderThemes)
    readonly property var theme: {
        if (!root.scanned && root.snapshot && root.snapshot.id === root.themeId)
            return root.snapshot;
        return ThemeProvider.findTheme(root.themes, root.themeId)
            || ThemeProvider.findTheme(root.themes, ThemeProvider.defaultTheme);
    }
    readonly property var colors: root.theme.colors
    // Whether the theme gallery shows, the step it opens on ("themes", or "wallpapers"
    // to pick another of the current theme's), and the theme it previews ("" for none),
    // whose colors the shell wears meanwhile. Its effects stay the active theme's.
    property bool galleryShown: false
    property string galleryStart: "themes"
    property string previewId: ""
    readonly property var previewTheme: root.previewId !== "" ? ThemeProvider.findTheme(root.themes, root.previewId) : null
    readonly property var shownColors: root.previewTheme ? root.previewTheme.colors : root.colors
    // Desktop wallpapers still loading; the gallery covers the desktop until none are.
    property int wallpapersLoading: 0

    // The wallpaper changed in place on `screen`: it already shows there, as in the
    // theme gallery, so that screen's desktop shows it at once, with no transition.
    signal placed(var screen)
    // The active theme's effects directory, "" for none.
    readonly property string activeEffectsDir: root.theme.effectsDir || ""
    // [Appearance] drawWallpaper: Speshell draws the desktop background, showing
    // the default wallpaper for themes without their own. Off by default so other
    // wallpaper tools keep working; themes still set colors and effects.
    readonly property bool wallpaperEnabled: ConfigService.settings.appearance.drawWallpaper
    // [Appearance] shuffleAtLaunch: off, wallpaper, theme, or both, picked at
    // random once the themes are known; "" until config.ini loads, which may ask for one.
    readonly property string launchShuffle: ConfigService.config ? ConfigService.config.appearance.shuffleAtLaunch : ""
    property bool launched: false
    // The wallpaper to draw: held back until the launch pick, so startup does not
    // show the saved one only to replace it.
    readonly property string shownWallpaper: root.launched ? root.wallpaper : ""
    // The active palette for other apps, which matugen renders into their themes.
    // See README "App themes".
    readonly property string palettePath: ConfigService.dataDir !== ""
        ? ConfigService.dataDir + "/palette.json"
        : ""
    readonly property var appPalette: root.launched
        ? ThemeProvider.appPalette(Theme.mergePalette(root.colors))
        : null

    // Rescans on opening, so new themes and wallpapers show up. `start`: the step
    // it opens on, "themes" by default.
    function openGallery(start) {
        if (!root.galleryShown)
            root.scan();
        root.galleryStart = start || "themes";
        root.galleryShown = true;
    }

    function closeGallery() {
        root.galleryShown = false;
    }

    function toggleGallery(start) {
        if (root.galleryShown)
            root.closeGallery();
        else
            root.openGallery(start);
    }

    // The wallpaper theme `id` comes with: its last one, otherwise its first.
    function wallpaperFor(id) {
        return ThemeProvider.themeWallpaper(root.wallpapers, id, root.chosen);
    }

    // `placedOn`: the screen it already shows on, if any; see placed().
    function setTheme(id, placedOn) {
        if (!ThemeProvider.findTheme(root.themes, id))
            return false;
        if (id !== root.themeId) {
            root.themeId = id;
            root.wallpaper = root.wallpaperFor(id);
            root.save();
            if (placedOn)
                root.placed(placedOn);
        }
        return true;
    }

    // A wallpaper brings its theme along.
    function setWallpaper(path, placedOn) {
        var next = String(path || "");
        var id = ThemeProvider.themeFor(next, root.themesDirs);
        if (!root.wallpaperEnabled || id === "")
            return false;
        if (next !== root.wallpaper || id !== root.themeId) {
            root.themeId = id;
            root.wallpaper = next;
            root.remember();
            root.save();
            if (placedOn)
                root.placed(placedOn);
        }
        if (!ThemeProvider.findTheme(root.folderThemes, id))
            root.scan();
        return true;
    }

    // A random wallpaper of a theme, the current one by default.
    function shuffle(id) {
        var next = ThemeProvider.pickRandom(root.wallpapers, id || root.themeId, root.wallpaper);
        return next !== "" && root.setWallpaper(next);
    }

    // Records the current wallpaper as its theme's.
    function remember() {
        if (root.wallpaper === "" || root.chosen[root.themeId] === root.wallpaper)
            return;
        var next = Object.assign({}, root.chosen);
        next[root.themeId] = root.wallpaper;
        root.chosen = next;
    }

    function save() {
        if (root.statePath === "")
            return;
        // FileView drops a write that starts while another is in flight, so queue it.
        if (root.saving) {
            root.saveQueued = true;
            return;
        }
        var theme = root.theme;
        root.snapshot = { id: theme.id, name: theme.name, effects: theme.effects, effectsDir: theme.effectsDir,
                          colors: theme.colors, errors: [] };
        root.saving = true;
        stateFile.setText(JSON.stringify({ theme: root.themeId, wallpaper: root.wallpaper, wallpapers: root.chosen,
                                           snapshot: root.snapshot }));
    }

    function finishSave() {
        root.saving = false;
        if (root.saveQueued) {
            root.saveQueued = false;
            root.save();
        }
    }

    function finishStateLoad(text) {
        var parsed = ({});
        try {
            parsed = JSON.parse(text || "{}");
        } catch (stateError) {
            parsed = ({});
        }
        if (parsed && typeof parsed.theme === "string" && parsed.theme !== "") {
            root.snapshot = parsed.snapshot && parsed.snapshot.colors ? parsed.snapshot : null;
            root.themeId = parsed.theme;
            root.wallpaper = typeof parsed.wallpaper === "string" ? parsed.wallpaper : "";
        }
        if (parsed && parsed.wallpapers && typeof parsed.wallpapers === "object")
            root.chosen = parsed.wallpapers;
        root.stateLoaded = true;
        // Later: FileView drops a write started inside its own loaded signal, and
        // reconciling may save.
        Qt.callLater(root.reconcile);
    }

    function scan() {
        if (scanProc.running) {
            scanProc.queued = true;
            return;
        }
        scanProc.dirs = root.scanDirs;
        scanProc.command = [
            "sh", "-c",
            "for dir in \"$1\" \"$2\"; do [ -d \"$dir\" ] || continue; "
                + "for f in \"$dir\"/*/theme.ini; do [ -f \"$f\" ] || continue; "
                + "printf 'theme\\t%s\\n' \"${f%/theme.ini}\"; awk '{ print \"ini\\t\" $0 }' \"$f\"; done; "
                + "find -L \"$dir\" -mindepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' "
                + "-o -iname '*.png' -o -iname '*.webp' \\) -printf 'wall\\t%p\\n'; done; "
                + "for dir in \"$3\" \"$4\"; do [ -d \"$dir\" ] || continue; for f in \"$dir\"/*/Effects.qml; do "
                + "[ -f \"$f\" ] && printf 'effects\\t%s\\n' \"${f%/Effects.qml}\"; done; done; true",
            "speshell-theme-scan",
            root.shippedThemesDir,
            root.themesDir,
            root.shippedEffectsDir,
            root.userEffectsDir
        ];
        scanProc.running = true;
    }

    function finishScan(text) {
        var library = ThemeProvider.parseScan(text, root.themesDirs);
        root.folderThemes = library.themes;
        root.wallpapers = library.wallpapers;
        root.scannedDirs = scanProc.dirs;
        root.scanned = true;
        root.reconcile();
    }

    function reconcile() {
        if (!root.scanned || root.scannedDirs !== root.scanDirs || !root.stateLoaded || root.launchShuffle === "")
            return;
        var before = root.themeId + "\n" + root.wallpaper;
        var chosenBefore = root.chosen;
        // The selection may have gone stale: a removed theme or wallpaper.
        if (!ThemeProvider.findTheme(root.themes, root.themeId)) {
            root.themeId = ThemeProvider.defaultTheme;
            root.wallpaper = "";
        }
        if (!root.launched) {
            if (root.launchShuffle === "theme" || root.launchShuffle === "both") {
                const id = ThemeProvider.pickRandomTheme(root.themes, root.themeId);
                if (id !== "") {
                    root.themeId = id;
                    root.wallpaper = root.wallpaperFor(id);
                }
            }
            if (root.launchShuffle === "wallpaper" || root.launchShuffle === "both") {
                const next = ThemeProvider.pickRandom(root.wallpapers, root.themeId, root.wallpaper);
                if (next !== "")
                    root.wallpaper = next;
            }
        }
        var own = root.wallpapers.filter(function(wallpaper) {
            return wallpaper.theme === root.themeId && wallpaper.path === root.wallpaper;
        });
        if (own.length === 0)
            root.wallpaper = root.wallpaperFor(root.themeId);
        root.remember();
        root.launched = true;
        // Keep the saved snapshot in step with edits to theme.ini.
        if (before !== root.themeId + "\n" + root.wallpaper || root.chosen !== chosenBefore || !root.snapshot || JSON.stringify(root.snapshot.colors) !== JSON.stringify(root.theme.colors)
                || root.snapshot.effectsDir !== root.theme.effectsDir || root.snapshot.effects !== root.theme.effects
                || root.snapshot.id !== root.themeId)
            root.save();
        root.report();
    }

    // Writes palette.json and has matugen render it into the app themes, when the
    // palette changed. Startup with the same theme leaves the apps alone.
    function exportPalette() {
        if (root.palettePath === "" || !root.appPalette)
            return;
        if (paletteProc.running) {
            paletteProc.queued = true;
            return;
        }
        paletteProc.command = [
            "sh", "-c",
            "path=$1; text=$2; mode=$3; [ \"$(cat \"$path\" 2>/dev/null)\" = \"$text\" ] && exit 0; "
                + "mkdir -p \"${path%/*}\" && printf '%s\\n' \"$text\" > \"$path.next\" || exit 1; "
                + "command -v gsettings >/dev/null && gsettings set org.gnome.desktop.interface color-scheme \"prefer-$mode\"; "
                + "if [ -f \"${XDG_CONFIG_HOME:-$HOME/.config}/matugen/config.toml\" ] && command -v matugen >/dev/null; then "
                + "matugen json \"$path.next\" -m \"$mode\" -q || { rm -f \"$path.next\"; exit 1; }; fi; "
                + "mv \"$path.next\" \"$path\"",
            "speshell-app-themes",
            root.palettePath,
            JSON.stringify(root.appPalette, null, 2),
            root.appPalette.mode
        ];
        paletteProc.running = true;
    }

    // Tell the user once about problems in the active theme's theme.ini.
    function report() {
        var theme = root.theme;
        var key = theme.id + "\n" + theme.errors.join("\n");
        if (theme.errors.length === 0 || key === root.reported)
            return;
        root.reported = key;
        NotificationService.addInternalNotification("theme", "Problems in theme '" + theme.name + "'",
            theme.errors.join("\n"));
    }

    Process {
        id: scanProc
        property bool queued: false
        property string dirs: ""
        stdout: StdioCollector {
            id: scanOutput
        }
        onExited: {
            root.finishScan(scanOutput.text);
            if (scanProc.queued) {
                scanProc.queued = false;
                root.scan();
            }
        }
    }

    Process {
        id: paletteProc
        property bool queued: false
        stderr: StdioCollector {
            id: paletteErrors
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                NotificationService.addInternalNotification("app-themes", "Apps did not take the theme",
                    paletteErrors.text.replace(/\x1b\[[0-9;]*m/g, "").trim() || "matugen exited with " + exitCode);
            if (paletteProc.queued) {
                paletteProc.queued = false;
                root.exportPalette();
            }
        }
    }

    FileView {
        id: stateFile
        path: root.statePath
        atomicWrites: true
        blockLoading: true
        printErrors: false
        onLoaded: root.finishStateLoad(stateFile.text())
        onLoadFailed: root.finishStateLoad("{}")
        onSaved: root.finishSave()
        onSaveFailed: root.finishSave()
    }

    onThemeIdChanged: root.report()
    onAppPaletteChanged: root.exportPalette()
    onLaunchShuffleChanged: root.reconcile()
    onThemesDirChanged: root.scan()
    onUserEffectsDirChanged: root.scan()
    // The folder may already be known when the service is first used.
    Component.onCompleted: root.scan()
}
