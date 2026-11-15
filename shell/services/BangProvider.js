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
    const results = [];
    const names = Object.keys(bangs || ({})).sort();
    for (let i = 0; i < names.length; i++) {
        if (names[i].indexOf(prefix) !== 0)
            continue;
        const suggestion = webResult(
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
    const raw = String(query || "").trim();
    const config = launcherConfig || ({});
    const bangs = config.bangs || ({});
    const body = raw.substring(1);
    const space = body.search(/\s/);
    const alias = (space < 0 ? body : body.substring(0, space)).toLowerCase();
    const terms = space < 0 ? "" : body.substring(space).trim();
    const actions = commands || [];

    if (space < 0) {
        let suggestions = actions.filter(command => {
            return command.bang.indexOf(alias) === 0;
        });
        suggestions = suggestions.concat(configuredBangResults(alias, bangs));
        if (suggestions.length > 0 || alias === "")
            return suggestions;
    }

    const action = actions.filter(command => command.bang === alias)[0];
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
    const raw = String(query || "").trim();
    const terms = raw.substring(1).trim();
    if (terms === "")
        return [];
    return [webResult(
        "search:" + terms,
        "Search the web for “" + terms + "”",
        "Open in your search engine",
        urlFromTemplate(launcherConfig.searchUrl, terms)
    )];
}
