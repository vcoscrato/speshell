import QtQuick
import QtTest
import "../shell/core/Config.js" as Config

TestCase {
    name: "Config"

    function messages(result) {
        return result.errors.map(function(error) { return error.message; }).join("\n");
    }

    // The package installs this file as a new user's config.ini.
    function test_exampleConfigIsValid() {
        var request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("../shell/config.example.ini"), false);
        request.send();
        verify(request.responseText.length > 0, "config.example.ini not read");
        var result = Config.parseAndValidate(request.responseText);
        verify(result.ok, messages(result));
    }

    function test_listSectionsKeepOrderAndCommas() {
        var result = Config.parseAndValidate("[Audio.QuickSwitch]\n1 = Speakers\n2 = Display, HDMI\n");
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

    // A laptop's defaults: warnings at 20 and 10%, the brightness left alone on battery,
    // no night light, and idling, on battery only, that dims, locks, turns the screen
    // off, and sleeps.
    function test_laptopDefaults() {
        var config = Config.defaults();
        compare(config.battery.lowLevel, 20);
        compare(config.battery.criticalLevel, 10);
        compare(config.backlight.batteryPercent, 0);
        compare([config.nightLight.enabled, config.nightLight.temperature], [false, 4000]);
        compare([config.idle.dimAfter, config.idle.lockAfter, config.idle.screenOffAfter, config.idle.sleepAfter], [2, 5, 6, 15]);
    }

    function test_idleTakesFractionsAndZero() {
        var result = Config.parseAndValidate("[Idle]\ndimAfter = 0.5\nsleepAfter = 0\n");
        verify(result.ok, messages(result));
        compare(result.config.idle.dimAfter, 0.5);
        compare(result.config.idle.sleepAfter, 0);
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

    // Panels write single keys into the user's file; the rest must survive.
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
