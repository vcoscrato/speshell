import QtQuick
import QtTest
import "../core/Config.js" as Config

TestCase {
    name: "Config"

    function messages(result) {
        return result.errors.map(function(error) { return error.message; }).join("\n");
    }

    // The package installs this file as a new user's config.ini.
    function test_exampleConfigIsValid() {
        var request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("../config.example.ini"), false);
        request.send();
        verify(request.responseText.length > 0, "config.example.ini not read");
        var result = Config.parseAndValidate(request.responseText);
        verify(result.ok, messages(result));
    }

    function test_listSectionsKeepOrderAndCommas() {
        var result = Config.parseAndValidate("[Audio.QuickSwitch]\n1 = Speakers\n2 = Display, HDMI\n");
        verify(result.ok, messages(result));
        compare(result.config.audioQuickSwitch, ["Speakers", "Display, HDMI"]);
    }

    function test_lockCommandTakesArguments() {
        var result = Config.parseAndValidate(
            "[Power]\nlockCommand = swaylock\n\n[Power.Arguments]\n1 = --daemonize\n2 = --color=00,00,00\n");
        verify(result.ok, messages(result));
        compare(result.config.powerMenu.lockCommand, ["swaylock", "--daemonize", "--color=00,00,00"]);
    }

    function test_rejectsInvalidValues_data() {
        return [
            { tag: "out of range", text: "[Appearance]\ntextScale = 1.75", message: "Expected a value from 0.8 to 1.5" },
            { tag: "not a number", text: "[Appearance]\ntextScale = large", message: "Expected a number" },
            { tag: "partial integer", text: "[Launcher]\nvisibleRows = 5rows", message: "Expected a whole number" },
            { tag: "not a boolean", text: "[Weather]\nenabled = yes", message: "Expected true or false" },
            { tag: "unknown choice", text: "[Bar]\nposition = left", message: "Expected one of" },
            { tag: "unknown power mode", text: "[Power]\nmode = turbo", message: "Expected one of" },
            { tag: "insecure URL", text: "[Launcher]\nsearchUrl = http://example.com/?q={query}", message: "must use HTTPS" },
            { tag: "missing placeholder", text: "[Launcher]\nsearchUrl = https://example.com/", message: "exactly one {query}" },
            { tag: "not a language", text: "[Tools]\ndictationLanguages = english", message: "is not a language code" },
            { tag: "malformed line", text: "[Appearance]\ntextScale 1.2", message: "Expected 'key = value'" }
        ];
    }

    // The tools take Tesseract's "eng+por" and a list of Whisper codes, however they're separated.
    function test_toolLanguagesAcceptAnySeparator() {
        var result = Config.parseAndValidate("[Tools]\nocrLanguages = eng, por\ndictationLanguages = en pt\n");
        verify(result.ok, messages(result));
        compare(result.config.tools.ocrLanguages, "eng+por");
        compare(result.config.tools.dictationLanguages, "en,pt");
    }

    function test_rejectsInvalidValues(data) {
        var result = Config.parseAndValidate(data.text);
        verify(!result.ok);
        verify(messages(result).indexOf(data.message) >= 0, messages(result));
    }

    // Settings writes single keys into the user's file; the rest must survive.
    function test_settingsEditKeepsTheRestOfTheFile() {
        var source = "# mine\n[Appearance]\ntextScale = 1.0\n\n[Weather]\nenabled = false\n";

        var replaced = Config.setIniProperty(source, "Appearance", "textScale", 1.2);
        compare(replaced, "# mine\n[Appearance]\ntextScale = 1.2\n\n[Weather]\nenabled = false\n");

        var inserted = Config.setIniProperty(replaced, "Weather", "location", "São Paulo");
        compare(inserted, "# mine\n[Appearance]\ntextScale = 1.2\n\n[Weather]\nenabled = false\nlocation = São Paulo\n");

        var appended = Config.setIniProperty(inserted, "Notifications", "maxVisible", 5);
        verify(appended.indexOf(inserted.trim()) === 0, appended);
        verify(appended.indexOf("[Notifications]\nmaxVisible = 5") >= 0, appended);
        verify(Config.parseAndValidate(appended).ok);
    }
}
