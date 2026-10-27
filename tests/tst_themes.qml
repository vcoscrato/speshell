import QtQuick
import QtTest
import "../shell/services/ThemeProvider.js" as ThemeProvider

TestCase {
    name: "Themes"

    readonly property string shippedDir: "/usr/share/speshell/themes"
    readonly property string themesDir: "/home/me/.config/speshell/themes"
    readonly property var themesDirs: [shippedDir, themesDir]
    readonly property string scan: [
        "theme\t" + shippedDir + "/fire",
        "ini\t[Theme]",
        "ini\tname = Fire",
        "ini\tdescription = Embers and ash.",
        "ini\teffects = fire",
        "ini\t[Colors]",
        "ini\taccent = #e5482e",
        "ini\tbase = #1d1416",
        "theme\t" + shippedDir + "/cosmos",
        "ini\t[Theme]",
        "ini\tname = Cosmos",
        "ini\teffects = cosmos",
        "theme\t" + themesDir + "/broken",
        "ini\t[Theme]",
        "ini\teffects = smoke",
        "ini\t[Colors]",
        "ini\ttext = white",
        "ini\tglow = #ffffff",
        "theme\t" + themesDir + "/cosmos",
        "ini\t[Theme]",
        "ini\tname = My Cosmos",
        "wall\t" + shippedDir + "/fire/agni-kai.jpg",
        "wall\t" + shippedDir + "/cosmos/galaxy.jpg",
        "wall\t" + themesDir + "/fire/zuko/ember_island.png",
        "wall\t" + themesDir + "/cosmos/galaxy.jpg",
        "wall\t" + themesDir + "/nord/fjord.webp",
        "wall\t" + themesDir + "/loose.jpg",
        "effects\t/usr/share/speshell/effects/fire",
        "effects\t/usr/share/speshell/effects/cosmos",
        "effects\t/home/me/.local/share/speshell/effects/fire",
        ""
    ].join("\n")

    function test_findsThemesAndWallpapers() {
        var parsed = ThemeProvider.parseScan(scan, themesDirs);
        compare(parsed.themes.map(function(t) { return t.id; }), ["broken", "fire", "cosmos", "nord"]);
        compare(parsed.wallpapers.map(function(w) { return w.theme; }), ["cosmos", "fire", "fire", "nord"]);
        var fire = ThemeProvider.findTheme(parsed.themes, "fire");
        compare(fire.name, "Fire");
        compare(fire.description, "Embers and ash.");
        compare(fire.colors.accent, "#e5482e");
    }

    function test_userFolderOverridesShipped() {
        var parsed = ThemeProvider.parseScan(scan, themesDirs);
        // The user's theme.ini replaces the shipped one, keys and all.
        var cosmos = ThemeProvider.findTheme(parsed.themes, "cosmos");
        compare(cosmos.name, "My Cosmos");
        compare(cosmos.effects, "");
        // So do the user's effects of the same name.
        compare(ThemeProvider.findTheme(parsed.themes, "fire").effectsDir,
            "/home/me/.local/share/speshell/effects/fire");
        // Wallpapers from both folders add up; the user's copy replaces the shipped one.
        compare(parsed.wallpapers.filter(function(w) { return w.theme === "fire"; }).length, 2);
        compare(parsed.wallpapers[0].path, themesDir + "/cosmos/galaxy.jpg");
    }

    function test_badThemeIniIsReportedNotApplied() {
        var broken = ThemeProvider.findTheme(ThemeProvider.parseScan(scan, themesDirs).themes, "broken");
        compare(broken.effectsDir, "");
        compare(broken.colors, ({}));
        verify(broken.errors[0].indexOf("effects 'smoke' are not installed") >= 0, broken.errors[0]);
    }

    function test_effectsCannotLeaveTheirFolder() {
        compare(ThemeProvider.parseTheme("x", "[Theme]\neffects = ../fire").effects, "");
    }

    function test_wallpaperBelongsToTheFolderItIsIn() {
        compare(ThemeProvider.themeFor(themesDir + "/fire/zuko/a.png", themesDirs), "fire");
        compare(ThemeProvider.themeFor(shippedDir + "/cosmos/galaxy.jpg", themesDirs), "cosmos");
        compare(ThemeProvider.themeFor(themesDir + "/loose.jpg", themesDirs), "");
        compare(ThemeProvider.themeFor("/elsewhere/fire/a.jpg", themesDirs), "");
        compare(ThemeProvider.themeFor(themesDir + "-old/fire/a.jpg", themesDirs), "");
    }

    function test_rememberedWallpaperFallsBack() {
        var parsed = ThemeProvider.parseScan(scan, themesDirs);
        var island = themesDir + "/fire/zuko/ember_island.png";
        compare(ThemeProvider.themeWallpaper(parsed.wallpapers, "fire", ({})), shippedDir + "/fire/agni-kai.jpg");
        compare(ThemeProvider.themeWallpaper(parsed.wallpapers, "fire", { "fire": island }), island);
        // A remembered wallpaper that is gone, or belongs to another theme, falls back.
        compare(ThemeProvider.themeWallpaper(parsed.wallpapers, "fire", { "fire": "/gone.jpg" }),
            shippedDir + "/fire/agni-kai.jpg");
        compare(ThemeProvider.themeWallpaper(parsed.wallpapers, "nord", { "nord": island }), themesDir + "/nord/fjord.webp");
        compare(ThemeProvider.themeWallpaper(parsed.wallpapers, "broken", undefined), "");
    }

    function test_fileUrlEscapesPaths() {
        compare(ThemeProvider.fileUrl("/a b/c#1.jpg"), "file:///a%20b/c%231.jpg");
        compare(ThemeProvider.fileUrl(""), "");
    }

    function test_appPaletteFollowsTheBackground() {
        var palette = ({});
        ThemeProvider.colorKeys.forEach(function(key) { palette[key] = "#808080"; });
        palette.base = "#1d1416";
        palette.crust = "#120c0d";
        palette.text = "#f3e3d3";
        palette.accent = "#e8b04a";
        var dark = ThemeProvider.appPalette(palette);
        compare(dark.mode, "dark");
        compare(dark.colors.primary.default.color, "#e8b04a");
        compare(dark.colors.on_primary.default.color, "#120c0d");
        compare(Object.keys(dark.base16).length, 16);

        palette.base = "#eff1f5";
        palette.crust = "#dce0e8";
        palette.text = "#4c4f69";
        palette.accent = "#1e66f5";
        var light = ThemeProvider.appPalette(palette);
        compare(light.mode, "light");
        compare(light.colors.on_primary.default.color, "#eff1f5");
    }
}
