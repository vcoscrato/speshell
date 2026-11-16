import QtQuick
import QtTest
import "../shell/core/Config.js" as Config

TestCase {
    name: "Config"

    function messages(result) {
        return result.errors.map(error => error.message).join("\n");
    }

    // The package installs this file as a new user's config.ini.
    function test_exampleConfigIsValid() {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("../shell/config.example.ini"), false);
        request.send();
        verify(request.responseText.length > 0, "config.example.ini not read");
        const result = Config.parseAndValidate(request.responseText);
        verify(result.ok, messages(result));
    }

    function test_listSectionsKeepOrderAndCommas() {
        const result = Config.parseAndValidate("[Audio.QuickSwitch]\n1 = Speakers\n2 = Display, HDMI\n");
        verify(result.ok, messages(result));
        compare(result.config.audio.quickSwitch, ["Speakers", "Display, HDMI"]);
    }

    function test_rejectsInvalidValues_data() {
        return [
            { tag: "out of range", text: "[Appearance]\ntextScale = 1.75", message: "Expected a value from 0.8 to 1.5" },
            { tag: "not a number", text: "[Appearance]\ntextScale = large", message: "Expected a number" },
            { tag: "partial integer", text: "[Launcher]\nvisibleRows = 5rows", message: "Expected a whole number" },
            { tag: "not a boolean", text: "[Weather]\nenabled = yes", message: "Expected true or false" },
            { tag: "unknown choice", text: "[Bar]\nposition = left", message: "Expected one of" },
            { tag: "unknown power mode", text: "[Power]\nmode = turbo", message: "Expected one of" },
            { tag: "night light too cold", text: "[NightLight]\ntemperature = 9000", message: "Expected a value from 1000 to 6500" },
            { tag: "idle minutes negative", text: "[Idle]\nlockAfter = -1", message: "Expected a value from 0 to 240" },
            { tag: "insecure URL", text: "[Launcher]\nsearchUrl = http://example.com/?q={query}", message: "must use HTTPS" },
            { tag: "missing placeholder", text: "[Launcher]\nsearchUrl = https://example.com/", message: "exactly one {query}" },
            { tag: "not a language", text: "[Tools]\ndictationLanguages = english", message: "is not a language code" },
            { tag: "malformed line", text: "[Appearance]\ntextScale 1.2", message: "Expected 'key = value'" }
        ];
    }

    function test_idleTakesFractionsAndZero() {
        const result = Config.parseAndValidate("[Idle]\ndimAfter = 0.5\nsleepAfter = 0\n");
        verify(result.ok, messages(result));
        compare(result.config.idle.dimAfter, 0.5);
        compare(result.config.idle.sleepAfter, 0);
    }

    // The tools take Tesseract's "eng+por" and a list of Whisper codes, however they're separated.
    function test_toolLanguagesAcceptAnySeparator() {
        const result = Config.parseAndValidate("[Tools]\nocrLanguages = eng, por\ndictationLanguages = en pt\n");
        verify(result.ok, messages(result));
        compare(result.config.tools.ocrLanguages, "eng+por");
        compare(result.config.tools.dictationLanguages, "en,pt");
    }

    function test_rejectsInvalidValues(data) {
        const result = Config.parseAndValidate(data.text);
        verify(!result.ok);
        verify(messages(result).indexOf(data.message) >= 0, messages(result));
    }

    // Panels write single keys into the user's file; the rest must survive.
    function test_settingsEditKeepsTheRestOfTheFile() {
        const source = "# mine\n[Appearance]\ntextScale = 1.0\n\n[Weather]\nenabled = false\n";

        const replaced = Config.setIniProperty(source, "Appearance", "textScale", 1.2);
        compare(replaced, "# mine\n[Appearance]\ntextScale = 1.2\n\n[Weather]\nenabled = false\n");

        const inserted = Config.setIniProperty(replaced, "Weather", "location", "São Paulo");
        compare(inserted, "# mine\n[Appearance]\ntextScale = 1.2\n\n[Weather]\nenabled = false\nlocation = São Paulo\n");

        const appended = Config.setIniProperty(inserted, "Notifications", "maxVisible", 5);
        verify(appended.indexOf(inserted.trim()) === 0, appended);
        verify(appended.indexOf("[Notifications]\nmaxVisible = 5") >= 0, appended);
        verify(Config.parseAndValidate(appended).ok);
    }
}
