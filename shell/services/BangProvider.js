.pragma library

function urlFromTemplate(template, query) {
    return String(template || "").replace("{query}", encodeURIComponent(String(query || "")));
}

// An action the launcher runs itself, such as !mirror; `keywords` find it in a plain search.
function commandResult(bang, title, detail, iconName, keywords) {
    return {
        id: "command:" + bang,
        kind: "command",
        title: title,
        subtitle: "!" + bang + " · " + detail,
        iconName: iconName,
        iconSource: "",
        badge: "ACTION",
        activatable: true,
        payload: { command: bang },
        completion: "!" + bang,
        bang: bang,
        keywords: keywords || ""
    };
}

function webResult(id, title, subtitle, url) {
    return {
        id: id,
        kind: "web",
        title: title,
        subtitle: subtitle,
        iconName: "web-search",
        iconSource: "",
        badge: "WEB",
        activatable: true,
        payload: { url: url }
    };
}

function configuredBangResults(prefix, bangs) {
    var results = [];
    var names = Object.keys(bangs || ({})).sort();
    for (var i = 0; i < names.length; i++) {
        if (names[i].indexOf(prefix) !== 0)
            continue;
        var suggestion = webResult(
            "bang:" + names[i],
            "!" + names[i],
            "Type a search for this site · Tab to complete",
            urlFromTemplate(bangs[names[i]], "")
        );
        // Activating a bare bang completes it instead of opening an empty search.
        suggestion.completion = "!" + names[i] + " ";
        suggestion.completeOnActivate = true;
        results.push(suggestion);
    }
    return results;
}

// `commands`: commandResult()s available right now.
function bangResults(query, launcherConfig, commands) {
    var raw = String(query || "").trim();
    var config = launcherConfig || ({});
    var bangs = config.bangs || ({});
    var body = raw.substring(1);
    var space = body.search(/\s/);
    var alias = (space < 0 ? body : body.substring(0, space)).toLowerCase();
    var terms = space < 0 ? "" : body.substring(space).trim();
    var actions = commands || [];

    if (space < 0) {
        var suggestions = actions.filter(function(command) {
            return command.bang.indexOf(alias) === 0;
        });
        suggestions = suggestions.concat(configuredBangResults(alias, bangs));
        if (suggestions.length > 0 || alias === "")
            return suggestions;
    }

    var action = actions.filter(function(command) { return command.bang === alias; })[0];
    if (action)
        return [action];

    if (Object.prototype.hasOwnProperty.call(bangs, alias)) {
        return [webResult(
            "bang:" + alias + ":" + terms,
            "Search !" + alias + (terms !== "" ? " for “" + terms + "”" : ""),
            "Your search shortcut",
            urlFromTemplate(bangs[alias], terms)
        )];
    }

    return [webResult(
        "bang:passthrough:" + body,
        "Search “" + raw + "”",
        "No shortcut by that name, so search the web for it",
        urlFromTemplate(config.searchUrl, raw)
    )];
}

function searchResult(query, launcherConfig) {
    var raw = String(query || "").trim();
    var terms = raw.substring(1).trim();
    if (terms === "")
        return [];
    return [webResult(
        "search:" + terms,
        "Search the web for “" + terms + "”",
        "Open in your search engine",
        urlFromTemplate(launcherConfig.searchUrl, terms)
    )];
}
