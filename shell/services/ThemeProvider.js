.pragma library
.import "../core/Config.js" as Config

// Themes: folders holding a theme.ini and wallpapers. Speshell ships some under
// themes/, and users add or override them under ~/.config/speshell/themes.
// See README "Themes".

var defaultTheme = "cosmos";

// Stands in for the Cosmos theme when its folder is missing, as in a broken install.
var fallbackTheme = { id: defaultTheme, name: "Cosmos", description: "", effects: "", effectsDir: "", colors: ({}), errors: [] };

var colorKeys = [
    "base", "mantle", "crust", "surface0", "surface1", "surface2", "overlay0",
    "text", "subtext0", "subtext1", "red", "peach", "yellow", "green", "teal", "sky",
    "blue", "pink", "rosewater", "accent"
];
// Colors Speshell no longer uses; older theme.ini files may still set them.
var retiredColorKeys = ["lavender", "mauve"];

function fileUrl(path) {
    return path ? "file://" + String(path).split("/").map(encodeURIComponent).join("/") : "";
}

function baseName(path) {
    return String(path).substring(String(path).lastIndexOf("/") + 1);
}

function titleFor(path) {
    var name = baseName(path).replace(/\.[^.]+$/, "");
    return name.replace(/[-_]+/g, " ").trim() || name;
}

// The path relative to the themes directory holding it, "theme/file", or "" for
// paths outside every themes directory or not inside a theme folder.
function themeRelative(path, themesDirs) {
    var dirs = [].concat(themesDirs || []);
    for (var i = 0; i < dirs.length; i++) {
        var prefix = String(dirs[i] || "") + "/";
        if (dirs[i] === "" || String(path).indexOf(prefix) !== 0)
            continue;
        var relative = String(path).substring(prefix.length);
        if (relative.indexOf("/") > 0)
            return relative;
    }
    return "";
}

// The theme folder holding path, or "".
function themeFor(path, themesDirs) {
    var relative = themeRelative(path, themesDirs);
    return relative.substring(0, relative.indexOf("/"));
}

// A theme folder's theme.ini text (possibly empty) as a theme. Colors it leaves out
// come from the Cosmos palette. `effects`, when given, maps installed effects
// names to their directories. Problems are kept in `errors`; the theme still
// applies with the offending keys left out.
function parseTheme(id, text, effects) {
    var document = Config.parseIni(text);
    var errors = document.errors.map(function(error) { return "line " + error.line + ": " + error.message; });
    function value(sectionName, key) {
        var found = Config.entry(document, sectionName, key);
        return found ? found.value : "";
    }
    var theme = {
        id: id,
        name: value("Theme", "name") || titleFor(id),
        description: value("Theme", "description"),
        effects: value("Theme", "effects"),
        effectsDir: "",
        colors: ({}),
        errors: errors
    };
    if (theme.effects !== "" && !/^[A-Za-z0-9_-]+$/.test(theme.effects)) {
        errors.push("effects must be a folder name");
        theme.effects = "";
    } else if (theme.effects !== "" && effects) {
        theme.effectsDir = effects[theme.effects] || "";
        if (theme.effectsDir === "")
            errors.push("effects '" + theme.effects + "' are not installed");
    }
    var colors = Config.section(document, "Colors");
    var keys = colors ? colors.keys : [];
    for (var i = 0; i < keys.length; i++) {
        var color = colors.values[keys[i]];
        if (retiredColorKeys.indexOf(keys[i]) >= 0)
            continue;
        if (colorKeys.indexOf(keys[i]) < 0)
            errors.push("line " + color.line + ": unknown color '" + keys[i] + "'");
        else if (!/^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(color.value))
            errors.push("line " + color.line + ": " + keys[i] + " must be #rrggbb");
        else
            theme.colors[keys[i]] = color.value;
    }
    return theme;
}

// ── App palette ─────────────────────────────────────────────

function rgbOf(hex) {
    var value = parseInt(String(hex).substring(1, 7), 16);
    return [(value >> 16) & 255, (value >> 8) & 255, value & 255];
}

function hexOf(rgb) {
    return "#" + rgb.map(function(channel) {
        return ("0" + Math.round(channel).toString(16)).slice(-2);
    }).join("");
}

// `from` moved `amount` (0–1) of the way to `to`.
function mix(from, to, amount) {
    var a = rgbOf(from);
    var b = rgbOf(to);
    return hexOf(a.map(function(channel, i) { return channel + (b[i] - channel) * amount; }));
}

function luminance(hex) {
    var rgb = rgbOf(hex).map(function(channel) {
        var c = channel / 255;
        return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    });
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2];
}

// Of `light` and `dark`, the one that reads better on `fill`.
function readableOn(fill, light, dark) {
    var l = luminance(fill);
    return (luminance(light) + 0.05) / (l + 0.05) >= (l + 0.05) / (luminance(dark) + 0.05) ? light : dark;
}

// A full palette (every colorKeys entry) as matugen's JSON, which `matugen json`
// renders app templates from: Speshell's own names, the Material roles matugen
// templates use, and base16. Themes have one look, so each color's dark, light,
// and default are the same. Each hue also comes as tints over base (green_15,
// green_30, green_50, by percent) for apps without transparency, since matugen
// cannot mix two colors.
function appPalette(p) {
    var dark = luminance(p.base) < 0.5;
    // The palette's ends, for text on filled colors.
    var deep = dark ? p.crust : p.text;
    var bright = dark ? p.text : p.base;
    var colors = ({});
    var roles = {
        source_color: p.accent, surface_tint: p.accent,
        primary: p.accent, secondary: p.blue, tertiary: p.pink, error: p.red,
        background: p.base, surface: p.base, surface_dim: p.base, surface_bright: p.surface1,
        surface_container_lowest: p.crust, surface_container_low: p.mantle, surface_container: p.surface0,
        surface_container_high: p.surface1, surface_container_highest: p.surface2, surface_variant: p.surface0,
        on_background: p.text, on_surface: p.text, on_surface_variant: p.subtext0,
        outline: p.overlay0, outline_variant: p.surface1,
        inverse_surface: p.text, inverse_on_surface: p.base, inverse_primary: mix(p.accent, deep, 0.4),
        shadow: "#000000", scrim: "#000000"
    };
    ["primary", "secondary", "tertiary", "error"].forEach(function(role) {
        roles["on_" + role] = readableOn(roles[role], bright, deep);
        roles[role + "_container"] = mix(p.base, roles[role], 0.3);
        roles["on_" + role + "_container"] = p.text;
        if (role !== "error") {
            roles[role + "_fixed"] = mix(roles[role], p.text, 0.6);
            roles[role + "_fixed_dim"] = mix(roles[role], p.text, 0.3);
            roles["on_" + role + "_fixed"] = deep;
            roles["on_" + role + "_fixed_variant"] = mix(deep, roles[role], 0.4);
        }
    });
    function add(name, hex) {
        colors[name] = { default: { color: hex }, dark: { color: hex }, light: { color: hex } };
    }
    colorKeys.forEach(function(key) { add(key, p[key]); });
    ["red", "peach", "yellow", "green", "teal", "sky", "blue", "pink", "accent"].forEach(function(hue) {
        [15, 30, 50].forEach(function(percent) { add(hue + "_" + percent, mix(p.base, p[hue], percent / 100)); });
    });
    Object.keys(roles).forEach(function(role) { add(role, roles[role]); });
    var base16 = ({});
    [p.base, p.mantle, p.surface0, p.surface1, p.surface2, p.text, p.rosewater, p.subtext1,
     p.red, p.peach, p.yellow, p.green, p.teal, p.blue, p.pink, p.accent].forEach(function(hex, i) {
        base16["base0" + i.toString(16)] = { default: { color: hex }, dark: { color: hex }, light: { color: hex } };
    });
    var mode = dark ? "dark" : "light";
    return { mode: mode, is_dark_mode: dark, colors: colors, base16: base16 };
}

// Scanner output lines:"theme<TAB>folder" starts a theme folder, "ini<TAB>line"
// adds a line of its theme.ini, "wall<TAB>path" lists a wallpaper, and
// "effects<TAB>dir" lists installed effects. Directories come in `themesDirs`
// order. A later theme.ini or effects directory replaces an earlier one of the
// same name. Wallpapers from every folder of a theme add up, a later one replacing
// an earlier one at the same place in the theme.
function parseScan(text, themesDirs) {
    var ini = ({});
    var order = [];
    var current = "";
    var paths = [];
    var effects = ({});
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var tab = lines[i].indexOf("\t");
        if (tab < 0)
            continue;
        var kind = lines[i].substring(0, tab);
        var value = lines[i].substring(tab + 1);
        if (kind === "theme") {
            current = baseName(value);
            if (!ini.hasOwnProperty(current))
                order.push(current);
            ini[current] = [];
        } else if (kind === "ini" && current !== "") {
            ini[current].push(value);
        } else if (kind === "wall") {
            paths.push(value);
        } else if (kind === "effects") {
            effects[baseName(value)] = value;
        }
    }

    var byPlace = ({});
    for (var j = 0; j < paths.length; j++) {
        var relative = themeRelative(paths[j], themesDirs);
        if (relative === "")
            continue;
        var id = relative.substring(0, relative.indexOf("/"));
        // A folder of wallpapers is a theme even without a theme.ini.
        if (!ini.hasOwnProperty(id)) {
            ini[id] = [];
            order.push(id);
        }
        byPlace[relative] = { path: paths[j], title: titleFor(paths[j]), theme: id };
    }
    var wallpapers = Object.keys(byPlace).map(function(key) { return byPlace[key]; });
    wallpapers.sort(function(a, b) {
        return a.theme === b.theme ? a.title.localeCompare(b.title) : a.theme.localeCompare(b.theme);
    });
    var themes = order.map(function(id) { return parseTheme(id, ini[id].join("\n"), effects); });
    themes.sort(function(a, b) { return a.name.localeCompare(b.name); });
    return { themes: themes, wallpapers: wallpapers };
}

// The scanned themes, with Cosmos standing in if it was not found.
function allThemes(themes) {
    return findTheme(themes, defaultTheme) ? (themes || []) : (themes || []).concat([fallbackTheme]);
}

function findTheme(themes, id) {
    for (var i = 0; i < (themes || []).length; i++) {
        if (themes[i].id === id)
            return themes[i];
    }
    return null;
}

// The wallpaper a theme comes with: the one last set for it while it is still
// there, otherwise its first. `chosen` maps theme ids to their last wallpaper.
// "" for a theme without wallpapers.
function themeWallpaper(wallpapers, theme, chosen) {
    var own = (wallpapers || []).filter(function(wallpaper) { return wallpaper.theme === theme; });
    var last = chosen && typeof chosen[theme] === "string" ? chosen[theme] : "";
    for (var i = 0; i < own.length; i++) {
        if (own[i].path === last)
            return last;
    }
    return own.length > 0 ? own[0].path : "";
}

// A random theme id other than `current`, or "" when there is no other.
function pickRandomTheme(themes, current) {
    var pool = (themes || []).filter(function(theme) { return theme.id !== current; });
    if (pool.length === 0)
        return "";
    return pool[Math.floor(Math.random() * pool.length)].id;
}

function pickRandom(wallpapers, theme, current) {
    var pool = (wallpapers || []).filter(function(wallpaper) {
        return wallpaper.theme === theme && wallpaper.path !== current;
    });
    if (pool.length === 0)
        return "";
    return pool[Math.floor(Math.random() * pool.length)].path;
}
