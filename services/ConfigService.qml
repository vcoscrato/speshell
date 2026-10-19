pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core/Config.js" as Config
import "Shell.js" as Shell

// config.ini: loads and validates it (Config.js), seeding it from config.example.ini
// on the first run, follows edits made outside Speshell, and writes the Settings
// panel's changes. Read the settings in force from `settings`.
Singleton {
    id: root

    readonly property string bundledExamplePath: Qt.resolvedUrl("../config.example.ini").toString().replace(/^file:\/\//, "")
    property string status: "idle"
    // The config.ini loaded: by section, as Config.js builds it. Null while it loads or
    // when it is invalid.
    property var config: null
    // The settings in force: the config last loaded, or the defaults before one is.
    // Read settings here; it never goes null.
    property var settings: Config.defaults()
    property var errors: []
    property string configPath: ""
    property string configDir: ""
    property string dataDir: ""
    property bool reloadQueued: false
    property string operationMessage: ""
    property bool operationFailed: false
    property string sourceText: ""
    property string writeText: ""
    property var pendingConfig: null
    property var previousConfig: null
    property bool savingConfig: false
    readonly property bool valid: root.status === "valid" && root.config !== null
    readonly property bool invalid: root.status === "invalid"
    readonly property bool loading: root.status === "loading"
    readonly property string errorReport: root.buildErrorReport()

    onConfigChanged: if (root.config) root.settings = root.config

    function load() {
        if (configLoadProc.running) {
            root.reloadQueued = true;
            return;
        }

        root.reloadQueued = false;
        root.status = "loading";
        root.config = null;
        root.errors = [];
        root.operationMessage = "";
        root.operationFailed = false;
        configLoadProc.command = [
            "sh", "-c",
            "config_root=\"${XDG_CONFIG_HOME:-$HOME/.config}\"; "
                + "data_root=\"${XDG_DATA_HOME:-$HOME/.local/share}\"; "
                + "config_dir=\"$config_root/speshell\"; "
                + "data_dir=\"$data_root/speshell\"; "
                + "ini_file=\"$config_dir/config.ini\"; "
                + "mkdir -p \"$config_dir\" \"$data_dir\" || exit 20; "
                + "printf '%s\\n%s\\n' \"$config_dir\" \"$data_dir\"; "
                + "if [ ! -e \"$ini_file\" ] && [ ! -L \"$ini_file\" ]; then "
                + "cp \"$1\" \"$ini_file\" 2>/dev/null || true; "
                + "fi; "
                + "if [ -e \"$ini_file\" ] || [ -L \"$ini_file\" ]; then "
                + "cat \"$ini_file\" || exit 21; "
                + "else cat \"$1\" || exit 22; fi",
            "speshell-config-loader",
            root.bundledExamplePath
        ];
        configLoadProc.running = true;
    }

    function failLoader(message) {
        root.config = null;
        root.errors = [{ kind: "io", path: root.configPath || "$", line: 0, column: 0, message: message }];
        root.status = "invalid";
    }

    function applyLoaderOutput(text, exitCode, stderrText) {
        var output = String(text || "");
        var nl1 = output.indexOf("\n");
        var nl2 = output.indexOf("\n", nl1 + 1);
        if (nl1 >= 0 && nl2 >= 0) {
            root.configDir = output.substring(0, nl1);
            root.dataDir = output.substring(nl1 + 1, nl2);
            root.configPath = root.configDir + "/config.ini";
        }

        if (exitCode !== 0) {
            var detail = String(stderrText || "").trim();
            root.failLoader(detail !== "" ? detail : "Could not read the configuration file (loader exit " + exitCode + ").");
            return;
        }
        if (nl1 < 0 || nl2 < 0) {
            root.failLoader("The configuration loader returned an unexpected response.");
            return;
        }

        var iniContent = output.substring(nl2 + 1);
        var result = Config.parseAndValidate(iniContent);
        if (!result.ok) {
            root.config = null;
            root.errors = result.errors;
            root.status = "invalid";
            return;
        }

        root.errors = [];
        root.sourceText = iniContent;
        root.config = result.config;
        root.status = "valid";
    }

    function setProperty(section, key, value) {
        if (!root.valid || root.savingConfig)
            return false;

        // Start from the file on disk so edits made outside Speshell are kept.
        var currentText = root.readConfigFile();
        if (String(currentText || "").trim() === "")
            currentText = root.sourceText;

        var updatedText = Config.setIniProperty(currentText, section, key, value);
        var parsed = Config.parseAndValidate(updatedText);
        if (!parsed.ok) {
            root.operationFailed = true;
            root.operationMessage = "Could not apply setting: " + (parsed.errors[0] ? parsed.errors[0].message : "invalid configuration");
            return false;
        }
        if (updatedText === currentText)
            return true;

        root.previousConfig = root.config;
        root.pendingConfig = parsed.config;
        root.writeText = updatedText;
        root.savingConfig = true;
        root.operationFailed = false;
        root.operationMessage = "";

        // Optimistically apply new config state
        root.config = parsed.config;

        configFile.setText(root.writeText);
        return true;
    }

    function readConfigFile() {
        if (root.configPath === "")
            return "";
        configFile.reload();
        configFile.waitForJob();
        return configFile.text();
    }

    function applyExternalChange() {
        if (root.savingConfig || root.loading)
            return;
        if (root.invalid) {
            root.load();
            return;
        }
        if (!root.valid)
            return;

        var text = root.readConfigFile();
        if (text === root.sourceText || String(text || "").trim() === "")
            return;

        var parsed = Config.parseAndValidate(text);
        if (!parsed.ok) {
            root.operationFailed = true;
            root.operationMessage = "config.ini has errors, so the previous settings stay active. "
                + root.diagnosticText(parsed.errors[0]);
            return;
        }

        root.sourceText = text;
        root.config = parsed.config;
        root.operationFailed = false;
        root.operationMessage = "";
        console.info("[Speshell] Applied config.ini changes.");
    }

    function finishConfigWrite(succeeded) {
        var nextConfig = root.pendingConfig;
        var oldConfig = root.previousConfig;
        if (succeeded)
            root.sourceText = root.writeText;

        root.writeText = "";
        root.pendingConfig = null;
        root.previousConfig = null;
        root.savingConfig = false;

        if (succeeded) {
            root.config = nextConfig;
            root.operationFailed = false;
            root.operationMessage = "";
        } else {
            root.config = oldConfig;
            root.operationFailed = true;
            root.operationMessage = "Could not save settings to config.ini.";
        }
    }

    function diagnosticText(diagnostic) {
        var location = "";
        if (diagnostic.line > 0) {
            location = "line " + diagnostic.line;
            if (diagnostic.column > 0)
                location += ", column " + diagnostic.column;
        } else if (diagnostic.path && diagnostic.path !== "$") {
            location = diagnostic.path;
        }
        return (location !== "" ? location + ": " : "") + String(diagnostic.message || "Invalid configuration.");
    }

    function buildErrorReport() {
        if (!root.invalid || root.errors.length === 0)
            return "";
        var lines = [
            "Speshell configuration error",
            "Version: " + SystemState.appVersion,
            "File: " + (root.configPath || "~/.config/speshell/config.ini"),
            ""
        ];
        for (var i = 0; i < root.errors.length; i++)
            lines.push((i + 1) + ". " + root.diagnosticText(root.errors[i]));
        return lines.join("\n");
    }

    function openConfig() {
        if (openConfigProc.running)
            return;
        var configHome = Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config");
        root.operationMessage = "";
        root.operationFailed = false;
        openConfigProc.command = Shell.editFileCommand(
            root.configPath !== "" ? root.configPath : configHome + "/speshell/config.ini"
        );
        openConfigProc.running = true;
    }

    function copyErrorReport() {
        if (copyReportProc.running || root.errorReport === "")
            return;
        root.operationMessage = "";
        root.operationFailed = false;
        copyReportProc.command = [
            "sh", "-c", "printf '%s' \"$1\" | wl-copy", "speshell-copy", root.errorReport
        ];
        copyReportProc.running = true;
    }

    Process {
        id: configLoadProc
        running: false
        stdout: StdioCollector { id: configOutput }
        stderr: StdioCollector { id: configErrorOutput }
        onExited: function(exitCode) {
            root.applyLoaderOutput(configOutput.text, exitCode, configErrorOutput.text);
            if (root.reloadQueued) {
                root.reloadQueued = false;
                Qt.callLater(root.load);
            }
        }
    }

    FileView {
        id: configFile
        path: root.configPath
        blockLoading: true
        atomicWrites: true
        printErrors: false
        watchChanges: true
        onFileChanged: root.applyExternalChange()
        onSaved: root.finishConfigWrite(true)
        onSaveFailed: root.finishConfigWrite(false)
    }

    Process {
        id: openConfigProc
        running: false
        onExited: function(exitCode) {
            if (exitCode !== 0) {
                root.operationFailed = true;
                root.operationMessage = "Could not open the configuration file.";
            }
        }
    }

    Process {
        id: copyReportProc
        running: false
        onExited: function(exitCode) {
            root.operationFailed = exitCode !== 0;
            root.operationMessage = exitCode === 0
                ? "Error report copied."
                : "Could not copy the report; select the text manually.";
        }
    }
}
