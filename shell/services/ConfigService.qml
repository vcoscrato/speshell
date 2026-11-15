pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core/Config.js" as Config
import "Shell.js" as Shell

// config.ini: loads and validates it (Config.js), seeding it from config.example.ini
// on the first run, follows edits made outside Speshell, and writes the panels'
// changes. Read the settings in force from `settings`.
Singleton {
    id: root

    // "idle" before the first load, "loading", "valid", or "invalid".
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
    property string operationMessage: ""
    property bool operationFailed: false
    // config.ini's text as last read or written.
    property string sourceText: ""
    // The text the panels' changes make, which `config` already reflects; it is
    // written once the write in flight, if any, is done.
    property string wantedText: ""
    // The text being written, "" when none is.
    property string writingText: ""
    readonly property bool writing: root.writingText !== ""
    readonly property bool valid: root.status === "valid" && root.config !== null
    readonly property bool invalid: root.status === "invalid"
    readonly property bool loading: root.status === "loading"
    readonly property string errorReport: root.buildErrorReport()

    onConfigChanged: if (root.config) root.settings = root.config

    function load() {
        if (loader.running) {
            loader.queued = true;
            return;
        }
        root.status = "loading";
        root.config = null;
        root.errors = [];
        root.clearMessage();
        loader.running = true;
    }

    function clearMessage() {
        root.operationMessage = "";
        root.operationFailed = false;
    }

    function fail(message) {
        root.operationFailed = true;
        root.operationMessage = message;
    }

    function failLoad(message) {
        root.config = null;
        root.errors = [{ kind: "io", path: root.configPath || "$", line: 0, column: 0, message: message }];
        root.status = "invalid";
    }

    // config.sh's output: the config and data directories, a line each, then config.ini.
    function finishLoad(output, exitCode, errorText) {
        const lines = output.split("\n");
        if (lines.length >= 3) {
            root.configDir = lines[0];
            root.dataDir = lines[1];
            root.configPath = root.configDir + "/config.ini";
        }
        if (exitCode !== 0) {
            const detail = errorText.trim();
            root.failLoad(detail !== "" ? detail : "Could not read the configuration file.");
            return;
        }
        if (lines.length < 3) {
            root.failLoad("The configuration loader returned an unexpected response.");
            return;
        }
        const text = lines.slice(2).join("\n");
        const result = Config.parseAndValidate(text);
        if (!result.ok) {
            root.config = null;
            root.errors = result.errors;
            root.status = "invalid";
            return;
        }
        root.errors = [];
        root.sourceText = text;
        root.wantedText = text;
        root.config = result.config;
        root.status = "valid";
    }

    // Sets `key` in [section] and writes config.ini, keeping the rest of the file;
    // `settings` follows at once. False when config.ini is invalid or the value is.
    function setProperty(section, key, value) {
        if (!root.valid)
            return false;
        // Onto the changes still to be written, or else the file on disk, so edits made
        // outside Speshell are kept.
        let base = root.writing ? root.wantedText : root.readConfigFile();
        if (base.trim() === "")
            base = root.sourceText;
        const text = Config.setIniProperty(base, section, key, value);
        const parsed = Config.parseAndValidate(text);
        if (!parsed.ok) {
            root.fail("Could not apply setting: " + (parsed.errors[0] ? parsed.errors[0].message : "invalid configuration"));
            return false;
        }
        if (text === base)
            return true;
        root.wantedText = text;
        root.config = parsed.config;
        root.clearMessage();
        if (!root.writing)
            root.write();
        return true;
    }

    function write() {
        root.writingText = root.wantedText;
        configFile.setText(root.writingText);
    }

    function finishWrite(succeeded) {
        const written = root.writingText;
        root.writingText = "";
        if (!succeeded) {
            // Back to what the file holds, dropping the changes not yet written.
            root.wantedText = root.sourceText;
            root.config = Config.parseAndValidate(root.sourceText).config;
            root.fail("Could not save settings to config.ini.");
            return;
        }
        root.sourceText = written;
        if (root.wantedText !== written)
            root.write();
    }

    function readConfigFile() {
        if (root.configPath === "")
            return "";
        configFile.reload();
        configFile.waitForJob();
        return configFile.text();
    }

    function applyExternalChange() {
        if (root.writing || root.loading)
            return;
        if (root.invalid) {
            root.load();
            return;
        }
        if (!root.valid)
            return;

        const text = root.readConfigFile();
        if (text === root.sourceText || text.trim() === "")
            return;
        const parsed = Config.parseAndValidate(text);
        if (!parsed.ok) {
            root.fail("config.ini has errors, so the previous settings stay active. "
                + root.diagnosticText(parsed.errors[0]));
            return;
        }
        root.sourceText = text;
        root.wantedText = text;
        root.config = parsed.config;
        root.clearMessage();
        console.info("[Speshell] Applied config.ini changes.");
    }

    function diagnosticText(diagnostic) {
        let location = "";
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
        return [
            "Speshell configuration error",
            "Version: " + SystemState.appVersion,
            "File: " + (root.configPath || "~/.config/speshell/config.ini"),
            ""
        ].concat(root.errors.map((error, i) => (i + 1) + ". " + root.diagnosticText(error))).join("\n");
    }

    function openConfig() {
        if (openConfigProc.running)
            return;
        const configHome = Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config");
        root.clearMessage();
        openConfigProc.command = Shell.editFileCommand(root.configPath !== "" ? root.configPath : configHome + "/speshell/config.ini");
        openConfigProc.running = true;
    }

    function copyErrorReport() {
        if (copyReportProc.running || root.errorReport === "")
            return;
        root.clearMessage();
        copyReportProc.command = ["wl-copy", "--", root.errorReport];
        copyReportProc.running = true;
    }

    Process {
        id: loader

        property bool queued: false

        command: Shell.script("config.sh", [Shell.localPath(Qt.resolvedUrl("../config.example.ini"))])
        stdout: StdioCollector { id: loaderOutput }
        stderr: StdioCollector { id: loaderErrors }
        onExited: exitCode => {
            root.finishLoad(loaderOutput.text, exitCode, loaderErrors.text);
            if (loader.queued) {
                loader.queued = false;
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
        onSaved: root.finishWrite(true)
        onSaveFailed: root.finishWrite(false)
    }

    Process {
        id: openConfigProc
        onExited: exitCode => {
            if (exitCode !== 0)
                root.fail("Could not open the configuration file.");
        }
    }

    Process {
        id: copyReportProc
        onExited: exitCode => {
            root.operationFailed = exitCode !== 0;
            root.operationMessage = exitCode === 0
                ? "Error report copied."
                : "Could not copy the report; select the text manually.";
        }
    }
}
