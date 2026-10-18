.pragma library

function hasOwn(value, key) {
    return Object.prototype.hasOwnProperty.call(value, key);
}

function addError(errors, path, line, message) {
    errors.push({ kind: "validation", path: path, line: line || 0, column: 1, message: message });
}

function parseIni(text) {
    var sections = Object.create(null);
    var errors = [];
    var current = null;
    var lines = String(text || "").replace(/^\uFEFF/, "").split(/\r?\n/);

    for (var i = 0; i < lines.length; i++) {
        var sourceLine = lines[i];
        var line = sourceLine.trim();
        var lineNumber = i + 1;
        if (line === "" || line.charAt(0) === "#" || line.charAt(0) === ";")
            continue;

        if (line.charAt(0) === "[") {
            var sectionMatch = line.match(/^\[([^\]]+)\]$/);
            if (!sectionMatch) {
                addError(errors, "$", lineNumber, "Malformed section header.");
                current = null;
                continue;
            }
            var sectionName = sectionMatch[1].trim();
            if (sectionName === "") {
                addError(errors, "$", lineNumber, "Section names must not be empty.");
                current = null;
                continue;
            }
            if (!hasOwn(sections, sectionName)) {
                sections[sectionName] = { values: Object.create(null), keys: [] };
            }
            current = sections[sectionName];
            continue;
        }

        if (!current) {
            addError(errors, "$", lineNumber, "Properties must appear inside a section.");
            continue;
        }

        var equalsIndex = sourceLine.indexOf("=");
        if (equalsIndex < 0) {
            addError(errors, "$", lineNumber, "Expected 'key = value'.");
            continue;
        }
        var key = sourceLine.substring(0, equalsIndex).trim();
        if (key === "") {
            addError(errors, "$", lineNumber, "Property names must not be empty.");
            continue;
        }
        if (!hasOwn(current.values, key))
            current.keys.push(key);
        current.values[key] = { value: sourceLine.substring(equalsIndex + 1).trim(), line: lineNumber };
    }

    return { sections: sections, errors: errors };
}

function section(document, name) {
    return hasOwn(document.sections, name) ? document.sections[name] : null;
}

function entry(document, sectionName, keyName) {
    var valueSection = section(document, sectionName);
    return valueSection && hasOwn(valueSection.values, keyName)
        ? valueSection.values[keyName]
        : null;
}

function pathFor(sectionName, keyName) {
    return "$[" + sectionName + "]." + keyName;
}

function stringValue(document, sectionName, keyName, fallback, errors, allowEmpty) {
    var valueEntry = entry(document, sectionName, keyName);
    if (!valueEntry)
        return fallback;
    if (!allowEmpty && valueEntry.value === "") {
        addError(errors, pathFor(sectionName, keyName), valueEntry.line, "Value must not be empty.");
        return fallback;
    }
    return valueEntry.value;
}

function integerValue(document, sectionName, keyName, fallback, minimum, maximum, errors) {
    var valueEntry = entry(document, sectionName, keyName);
    if (!valueEntry)
        return fallback;
    if (!/^-?\d+$/.test(valueEntry.value)) {
        addError(errors, pathFor(sectionName, keyName), valueEntry.line, "Expected a whole number.");
        return fallback;
    }
    var value = Number(valueEntry.value);
    if (value < minimum || value > maximum) {
        addError(errors, pathFor(sectionName, keyName), valueEntry.line, "Expected a value from " + minimum + " to " + maximum + ".");
        return fallback;
    }
    return value;
}

function realValue(document, sectionName, keyName, fallback, minimum, maximum, errors) {
    var valueEntry = entry(document, sectionName, keyName);
    if (!valueEntry)
        return fallback;
    if (!/^-?(?:\d+(?:\.\d+)?|\.\d+)$/.test(valueEntry.value)) {
        addError(errors, pathFor(sectionName, keyName), valueEntry.line, "Expected a number.");
        return fallback;
    }
    var value = Number(valueEntry.value);
    if (!isFinite(value) || value < minimum || value > maximum) {
        addError(errors, pathFor(sectionName, keyName), valueEntry.line, "Expected a value from " + minimum + " to " + maximum + ".");
        return fallback;
    }
    return value;
}

function booleanValue(document, sectionName, keyName, fallback, errors) {
    var valueEntry = entry(document, sectionName, keyName);
    if (!valueEntry)
        return fallback;
    var value = valueEntry.value.toLowerCase();
    if (value !== "true" && value !== "false") {
        addError(errors, pathFor(sectionName, keyName), valueEntry.line, "Expected true or false.");
        return fallback;
    }
    return value === "true";
}

function enumValue(document, sectionName, keyName, fallback, allowed, errors) {
    var valueEntry = entry(document, sectionName, keyName);
    if (!valueEntry)
        return fallback;
    if (allowed.indexOf(valueEntry.value) < 0) {
        addError(errors, pathFor(sectionName, keyName), valueEntry.line, "Expected one of: " + allowed.join(", ") + ".");
        return fallback;
    }
    return valueEntry.value;
}

function urlValue(document, sectionName, keyName, fallback, errors) {
    var valueEntry = entry(document, sectionName, keyName);
    if (!valueEntry)
        return fallback;
    var value = valueEntry.value;
    var path = pathFor(sectionName, keyName);
    if (!/^https:\/\//i.test(value))
        addError(errors, path, valueEntry.line, "URL templates must use HTTPS.");
    var placeholder = value.indexOf("{query}");
    if (placeholder < 0 || value.indexOf("{query}", placeholder + 1) >= 0)
        addError(errors, path, valueEntry.line, "URL templates must contain exactly one {query} placeholder.");
    return value;
}

// Whitespace-separated codes, each matching `pattern`, joined by `separator`.
function codesValue(document, sectionName, keyName, fallback, pattern, separator, errors) {
    var valueEntry = entry(document, sectionName, keyName);
    if (!valueEntry)
        return fallback;
    var codes = valueEntry.value.split(/[\s,+]+/).filter(function(code) { return code !== ""; });
    for (var i = 0; i < codes.length; i++) {
        if (!pattern.test(codes[i])) {
            addError(errors, pathFor(sectionName, keyName), valueEntry.line, "'" + codes[i] + "' is not a language code.");
            return fallback;
        }
    }
    return codes.join(separator);
}

function sectionList(document, sectionName, errors) {
    var valueSection = section(document, sectionName);
    var result = [];
    if (!valueSection)
        return result;
    for (var i = 0; i < valueSection.keys.length; i++) {
        var key = valueSection.keys[i];
        var valueEntry = valueSection.values[key];
        if (valueEntry.value === "")
            addError(errors, pathFor(sectionName, key), valueEntry.line, "List entries must not be empty.");
        else
            result.push(valueEntry.value);
    }
    return result;
}

function sectionMap(document, sectionName, errors) {
    var valueSection = section(document, sectionName);
    var result = Object.create(null);
    if (!valueSection)
        return result;
    for (var i = 0; i < valueSection.keys.length; i++) {
        var key = valueSection.keys[i];
        var valueEntry = valueSection.values[key];
        if (valueEntry.value === "") {
            addError(errors, pathFor(sectionName, key), valueEntry.line, "Invalid map entry.");
            continue;
        }
        result[key] = valueEntry.value;
    }
    return result;
}

function bangsValue(document, errors) {
    var valueSection = section(document, "Launcher.Bangs");
    var result = Object.create(null);
    if (!valueSection)
        return result;
    for (var i = 0; i < valueSection.keys.length; i++) {
        var key = valueSection.keys[i];
        var valueEntry = valueSection.values[key];
        var path = pathFor("Launcher.Bangs", key);
        if (!/^[a-z0-9][a-z0-9-]{0,31}$/.test(key))
            addError(errors, path, valueEntry.line, "Bang names must use lowercase letters, digits, or hyphens.");
        if (!/^https:\/\//i.test(valueEntry.value) || valueEntry.value.split("{query}").length !== 2)
            addError(errors, path, valueEntry.line, "Bang URLs must use HTTPS and contain exactly one {query} placeholder.");
        result[key] = valueEntry.value;
    }
    return result;
}

function parseAndValidate(iniText) {
    var source = String(iniText || "");
    if (source.trim() === "")
        return { ok: false, config: null, errors: [{ kind: "validation", path: "$", line: 1, column: 1, message: "The configuration file is empty." }] };

    var document = parseIni(source);
    var errors = document.errors.slice();

    var lockCommand = stringValue(document, "Power", "lockCommand", "hyprlock", errors, false);
    var lockArguments = sectionList(document, "Power.Arguments", errors);
    var maxVisibleEntry = entry(document, "Notifications", "maxVisible");
    var maxVisible = maxVisibleEntry && maxVisibleEntry.value === "-1"
        ? -1
        : integerValue(document, "Notifications", "maxVisible", 3, 1, 50, errors);

    var config = {
        drawWallpaper: booleanValue(document, "Appearance", "drawWallpaper", false, errors),
        textScale: realValue(document, "Appearance", "textScale", 1.0, 0.8, 1.5, errors),
        launcherTransitionSpeed: realValue(document, "Appearance", "launcherTransitionSpeed", 1.0, 0, 3, errors),
        controlEffectsSpeed: realValue(document, "Appearance", "controlEffectsSpeed", 1.0, 0, 3, errors),
        wallpaperTransitionSpeed: realValue(document, "Appearance", "wallpaperTransitionSpeed", 1.0, 0, 3, errors),
        shuffleAtLaunch: enumValue(document, "Appearance", "shuffleAtLaunch", "off", ["off", "wallpaper", "theme", "both"], errors),
        audioScrollStep: integerValue(document, "Audio", "scrollStep", 5, 1, 100, errors),
        audioQuickSwitch: sectionList(document, "Audio.QuickSwitch", errors),
        audioDeviceNames: sectionMap(document, "Audio.DeviceNames", errors),
        audioInputQuickSwitch: sectionList(document, "Audio.InputQuickSwitch", errors),
        audioInputDeviceNames: sectionMap(document, "Audio.InputDeviceNames", errors),
        launcher: {
            width: integerValue(document, "Launcher", "width", 540, 280, 1200, errors),
            visibleRows: integerValue(document, "Launcher", "visibleRows", 5, 1, 20, errors),
            searchUrl: urlValue(document, "Launcher", "searchUrl", "https://duckduckgo.com/?q={query}", errors),
            bangs: bangsValue(document, errors)
        },
        backlightDevice: stringValue(document, "Backlight", "device", "", errors, true),
        powerMenu: { lockCommand: [lockCommand].concat(lockArguments) },
        powerMode: enumValue(document, "Power", "mode", "balanced", ["maximum", "balanced", "saver"], errors),
        weatherEnabled: booleanValue(document, "Weather", "enabled", false, errors),
        weatherLocation: stringValue(document, "Weather", "location", "", errors, true),
        maxVisibleNotification: maxVisible,
        tools: {
            ocrLanguages: codesValue(document, "Tools", "ocrLanguages", "eng", /^[A-Za-z0-9_]+$/, "+", errors) || "eng",
            dictationLanguages: codesValue(document, "Tools", "dictationLanguages", "", /^[a-z]{2,3}$/, ",", errors),
            dictationVocabulary: stringValue(document, "Tools", "dictationVocabulary", "", errors, true),
            dictationModel: stringValue(document, "Tools", "dictationModel", "", errors, true)
        },
        bar: {
            position: enumValue(document, "Bar", "position", "top", ["top", "bottom"], errors),
            height: integerValue(document, "Bar", "height", 40, 24, 64, errors),
            width: integerValue(document, "Bar", "width", 100, 20, 100, errors),
            margin: integerValue(document, "Bar", "margin", 0, 0, 64, errors),
            gap: integerValue(document, "Bar", "gap", 0, 0, 64, errors),
            outline: enumValue(document, "Bar", "outline", "edges", ["edges", "full"], errors)
        }
    };

    return errors.length > 0
        ? { ok: false, config: null, errors: errors }
        : { ok: true, config: config, errors: [] };
}

function setIniProperty(sourceText, sectionName, keyName, newValue) {
    var lines = String(sourceText || "").split(/\r?\n/);
    var sectionStart = -1;
    var sectionEnd = lines.length;
    for (var i = 0; i < lines.length; i++) {
        var header = lines[i].trim().match(/^\[([^\]]+)\]$/);
        if (!header)
            continue;
        if (sectionStart >= 0) {
            sectionEnd = i;
            break;
        }
        if (header[1].trim() === sectionName)
            sectionStart = i;
    }

    var value = String(newValue === undefined || newValue === null ? "" : newValue).replace(/[\r\n]+/g, " ").trim();
    var replacement = keyName + " =" + (value !== "" ? " " + value : "");
    if (sectionStart >= 0) {
        for (var entryIndex = sectionStart + 1; entryIndex < sectionEnd; entryIndex++) {
            var equalsIndex = lines[entryIndex].indexOf("=");
            if (equalsIndex >= 0 && lines[entryIndex].substring(0, equalsIndex).trim() === keyName) {
                lines[entryIndex] = replacement;
                return lines.join("\n");
            }
        }
        // After the section's last line, not after the blank lines that close it.
        var insertAt = sectionEnd;
        while (insertAt > sectionStart + 1 && lines[insertAt - 1].trim() === "")
            insertAt--;
        lines.splice(insertAt, 0, replacement);
        return lines.join("\n");
    }

    if (lines.length > 0 && lines[lines.length - 1].trim() !== "")
        lines.push("");
    lines.push("[" + sectionName + "]", replacement);
    return lines.join("\n");
}
