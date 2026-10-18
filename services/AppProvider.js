.pragma library

function lower(value) {
    return String(value || "").toLowerCase();
}

function normalizeWords(value) {
    var text = lower(value).replace(/[^a-z0-9]+/g, " ").trim();
    return text === "" ? [] : text.split(/\s+/);
}

function joinList(value) {
    if (!value)
        return "";
    if (Array.isArray(value))
        return value.join(" ");
    if ("length" in value) {
        var items = [];
        for (var i = 0; i < value.length; i++)
            items.push(value[i]);
        return items.join(" ");
    }
    return String(value || "");
}

// First letters of each name word, including camelCase parts: "vsc" for
// "Visual Studio Code", "ghd" for "GitHub Desktop".
function initials(name) {
    var words = normalizeWords(String(name || "").replace(/([a-z])([A-Z])/g, "$1 $2"));
    return words.map(function(word) { return word.charAt(0); }).join("");
}

// Characters of word in order within text; lower spread scores better.
function subsequenceSpread(text, word) {
    var start = -1;
    var position = -1;
    for (var i = 0; i < word.length; i++) {
        position = text.indexOf(word.charAt(i), position + 1);
        if (position < 0)
            return -1;
        if (start < 0)
            start = position;
    }
    return position - start - (word.length - 1);
}

function buildIndex(entries) {
    var result = [];
    for (var i = 0; i < entries.length; i++) {
        var entry = entries[i];
        if (!entry || entry.noDisplay || !entry.name)
            continue;
        var searchable = [
            entry.name || "",
            entry.genericName || "",
            entry.comment || "",
            entry.id || "",
            joinList(entry.categories),
            joinList(entry.keywords)
        ].join(" ");
        result.push({
            id: entry.id || "",
            title: entry.name || "",
            subtitle: entry.genericName || entry.comment || entry.id || "",
            iconSource: entry.icon || "",
            entry: entry,
            nameLower: lower(entry.name),
            genericLower: lower(entry.genericName),
            initialsLower: initials(entry.name),
            searchLower: lower(searchable)
        });
    }
    return result;
}

// Non-app items ({ id, title, keywords, result }) ranked with apps. They only
// appear for non-empty queries and activate their prebuilt result.
function buildExtraIndex(items) {
    return (items || []).map(function(item) {
        return {
            id: item.id,
            title: item.title,
            nameLower: lower(item.title),
            genericLower: "",
            initialsLower: initials(item.title),
            searchLower: lower(item.title + " " + (item.keywords || "")),
            requiresQuery: true,
            result: item.result
        };
    });
}

function usageCount(usage, id) {
    var value = usage && id ? usage[id] : null;
    if (typeof value === "number")
        return Math.max(0, value);
    return value && typeof value === "object" ? Math.max(0, Number(value.count) || 0) : 0;
}

function score(item, words) {
    if (words.length === 0)
        return 1000;
    var total = 0;
    for (var i = 0; i < words.length; i++) {
        var word = words[i];
        var wordScore = -1;
        if (item.nameLower === word)
            wordScore = 0;
        else if (item.nameLower.indexOf(word) === 0)
            wordScore = 5 + item.nameLower.length;
        else if (item.nameLower.indexOf(word) >= 0)
            wordScore = 30 + item.nameLower.indexOf(word);
        else if (item.genericLower.indexOf(word) >= 0)
            wordScore = 80 + item.genericLower.indexOf(word);
        else if (item.searchLower.indexOf(word) >= 0)
            wordScore = 140 + item.searchLower.indexOf(word);
        else if (word.length >= 2 && item.initialsLower.indexOf(word) === 0)
            wordScore = 60 + item.initialsLower.length;
        else if (word.length >= 3 && subsequenceSpread(item.nameLower, word) >= 0)
            wordScore = 400 + subsequenceSpread(item.nameLower, word);
        if (wordScore < 0)
            return -1;
        total += wordScore;
    }
    return total;
}

function search(index, query, usage, limit) {
    var words = normalizeWords(query);
    var matches = [];
    for (var i = 0; i < index.length; i++) {
        if (index[i].requiresQuery && words.length === 0)
            continue;
        var baseScore = score(index[i], words);
        if (baseScore < 0)
            continue;
        var launches = usageCount(usage, index[i].id);
        var boostCap = words.length > 0 ? 25 : 320;
        var boost = launches > 0 ? Math.min(boostCap, Math.log(launches + 1) * 90) : 0;
        matches.push({ item: index[i], score: baseScore, rankScore: baseScore - boost, launches: launches });
    }
    matches.sort(function(a, b) {
        if (a.rankScore !== b.rankScore) return a.rankScore - b.rankScore;
        if (a.launches !== b.launches) return b.launches - a.launches;
        if (a.score !== b.score) return a.score - b.score;
        return a.item.nameLower.localeCompare(b.item.nameLower);
    });

    var results = [];
    var count = Math.min(matches.length, limit || 100);
    for (var j = 0; j < count; j++) {
        var item = matches[j].item;
        if (item.result) {
            results.push(item.result);
            continue;
        }
        results.push({
            id: "app:" + item.id,
            kind: "app",
            title: item.title,
            subtitle: item.subtitle,
            iconName: "apps",
            iconSource: item.iconSource,
            badge: "APP",
            activatable: true,
            payload: { entry: item.entry, appId: item.id }
        });
    }
    return results;
}
