import QtQuick
import QtTest
import "../shell/services/AppProvider.js" as AppProvider
import "../shell/services/BangProvider.js" as BangProvider

TestCase {
    name: "Launcher"

    property var entries: [
        {
            id: "org.example.Editor.desktop",
            name: "Text Editor",
            genericName: "Code Editor",
            comment: "Edit source files",
            categories: ["Development"],
            keywords: ["code", "text"],
            noDisplay: false,
            icon: "editor"
        },
        {
            id: "org.example.Browser.desktop",
            name: "Web Browser",
            genericName: "Browser",
            comment: "Browse the web",
            categories: ["Network"],
            keywords: ["internet"],
            noDisplay: false,
            icon: "browser"
        },
        {
            id: "com.visualstudio.code.desktop",
            name: "Visual Studio Code",
            genericName: "",
            comment: "",
            categories: [],
            keywords: [],
            noDisplay: false,
            icon: "code"
        },
        { id: "hidden.desktop", name: "Hidden", noDisplay: true }
    ]
    readonly property var config: ({
        searchUrl: "https://example.com/?q={query}",
        bangs: { docs: "https://docs.example.com/?q={query}" }
    })

    function topResult(query, usage) {
        var results = AppProvider.search(AppProvider.buildIndex(entries), query, usage || {}, 10);
        return results.length > 0 ? results[0].title : "";
    }

    function test_hiddenEntriesAreLeftOut() {
        compare(AppProvider.buildIndex(entries).length, 3);
        compare(topResult("hidden"), "");
    }

    function test_matchesNamesAndKeywords() {
        compare(topResult("text edit"), "Text Editor");
        compare(topResult("internet"), "Web Browser");
    }

    function test_matchesInitialsAndSkippedLetters() {
        compare(topResult("vsc"), "Visual Studio Code");
        compare(topResult("brwsr"), "Web Browser");
        compare(topResult("zzz"), "");
    }

    function test_nameOutranksKeyword() {
        compare(topResult("code"), "Visual Studio Code");
    }

    function test_emptyQueryRanksByUsage() {
        compare(topResult("", { "org.example.Browser.desktop": { count: 5 } }), "Web Browser");
    }

    function test_bangEncodesItsQuery() {
        var results = BangProvider.bangResults("!docs qml singleton", config, []);
        compare(results.length, 1);
        compare(results[0].payload.url, "https://docs.example.com/?q=qml%20singleton");
    }

    function test_bangPrefixSuggestsActionsAndShortcuts() {
        var mirror = BangProvider.commandResult("mirror", "Mirror displays", "Show this display on all of them", "display");
        var results = BangProvider.bangResults("!", config, [mirror]);
        compare(results.map(function(result) { return result.id; }), ["command:mirror", "bang:docs"]);
        compare(BangProvider.bangResults("!mi", config, [mirror])[0].id, "command:mirror");
    }

    function test_unknownBangSearchesTheWeb() {
        compare(BangProvider.searchResult("? qml singleton", config)[0].payload.url,
            "https://example.com/?q=qml%20singleton");
        compare(BangProvider.bangResults("!unknown cats", config, [])[0].payload.url,
            "https://example.com/?q=!unknown%20cats");
    }
}
