pragma ComponentBehavior: Bound
pragma Singleton

import QtQml
import QtQuick
import Quickshell
import Quickshell.Io
import "Shell.js" as Shell

// This machine as its modules declare it, from system/speshell-system, which also makes
// every edit the System window asks for, and runs its apply and update. What those ask,
// sudo's password, a run line's question, paru's review of what it builds, comes back
// from system/speshell-ask as `ask`, and the window answers. A run goes on with the
// window closed, as a chip in the bar that rings when the run asks something and stays
// with its result until the window shows it. Nothing else runs while the window is
// closed: opening it reads the machine again. While it
// is open, the status refreshes after each edit and run, whenever a module's .conf
// changes, by hand or by an agent, and whenever an apply or update elsewhere
// ends, which the engine notes in its state.
Singleton {
    id: root

    // Whether the System window is open.
    property bool shown: false

    readonly property string command: Qt.resolvedUrl("../system/speshell-system").toString().replace(/^file:\/\//, "")
    // The modules' directory, with each module's .conf and files/, and the engine's state.
    readonly property string root: ConfigService.configDir !== "" ? ConfigService.configDir + "/system" : ""
    readonly property string statePath: ConfigService.dataDir !== "" ? ConfigService.dataDir + "/system/state.json" : ""

    // `speshell system status --json`; null until it first answers.
    property var status: null
    readonly property bool configured: root.status !== null && root.status.configured !== false
    readonly property string host: root.status ? root.status.host : ""
    // This machine's module, named after it; "" when there is none.
    readonly property string machine: root.configured ? root.status.machine : ""
    // What doesn't read: [{ file, line, message }], file relative to the modules'
    // directory, and line 0 when it isn't about one.
    readonly property var errors: root.configured ? root.status.errors : []
    readonly property var modules: root.configured ? root.status.modules : []
    readonly property var plan: root.configured ? root.status.plan : []
    readonly property var undeclared: root.configured ? root.status.undeclared : []
    // What comes from the AUR: installed from it, or wanted and in no repository, as
    // { name, module, explicit, installed }, and their names as a set.
    readonly property var aur: root.configured ? root.status.aur.slice().sort((a, b) => a.name.localeCompare(b.name)) : []
    readonly property var fromAur: {
        const names = {};
        for (const pkg of root.aur)
            names[pkg.name] = true;
        return names;
    }
    readonly property var drift: root.configured ? root.status.drift : []
    readonly property int decisions: root.undeclared.length + root.drift.length
    // Undeclared packages to remove on the next apply.
    property var removals: []

    // Updates waiting, from the repositories and the AUR; -1 until counted, which opening
    // the window does again once the count is a few minutes old, or an apply ended.
    property int updates: -1
    property double updatesCountedAt: 0
    // When the last apply or update here ended, in ms; 0 before the first.
    readonly property double appliedAt: root.configured ? root.status.applied * 1000 : 0
    // Whether an apply or an update runs, here or in a terminal.
    readonly property bool running: runProc.running || terminalProc.running
    property string errorText: ""

    // The apply or update run here: "apply" or "update", and "running", "done", or
    // "failed", until the window lets it go.
    property string runKind: ""
    property string runState: ""
    readonly property bool runActive: root.runState === "running"
    // Whether the window showed its result, and the bar's chip can go.
    property bool runSeen: true
    // The step it is on, from the engine's "» " headings, and the last other line.
    property string runStep: ""
    property string runLast: ""
    // Its output, the last few thousand lines, as { text, kind, note } rows, kind being
    // "heading" for a step and "" for anything else; the window's CodeView shows them.
    readonly property ListModel runLog: ListModel {}
    property var runArgs: []
    // Proves an ask comes from this run; speshell-ask gets it as SPESHELL_WINDOW.
    property string runToken: ""

    // What the run waits on: { answer, kind, subject }, answer being the FIFO to answer
    // on and kind "password", "secret", "text", or "review"; null when nothing.
    property var request: null
    // For a review, the packages paru would build: [{ name, state, text }].
    property var reviewPackages: []
    property string requestError: ""
    readonly property bool checkingPassword: passwordCheck.running
    // sudo's password once it proved right, for the rest of the run's sudo calls; the
    // run's end forgets it.
    property string password: ""
    // Answers waiting to be written: [{ answer, line }].
    property var replies: []
    readonly property string askDir: Quickshell.env("XDG_RUNTIME_DIR") + "/speshell-ask."

    // The search's results from the repositories and then the AUR, as each answers: the
    // packages to add, { name, repo, version, popularity, description, installed }, best
    // matches first.
    property string searchQuery: ""
    property var repoResults: []
    property var aurResults: []
    readonly property bool searching: searchDelay.running || searchProc.running
    // Whether the AUR has yet to answer, the repositories having answered.
    property bool aurPending: false

    // The run in the bar: running, asking, which rings, or ended with its result unseen.
    // A click opens the window.
    readonly property var runActivity: {
        const update = root.runKind === "update";
        const failed = root.runState === "failed";
        const asking = root.request !== null;
        const ended = !root.runActive && root.runState !== "" && !root.runSeen;
        return {
            id: "run",
            state: asking ? "active" : root.runActive ? "busy" : ended ? (failed ? "error" : "active") : "inactive",
            label: asking ? "System needs you" : root.runActive ? (update ? "Updating" : "Applying")
                : failed ? (update ? "Update stopped" : "Apply stopped") : (update ? "Updated" : "Applied"),
            detail: asking ? ({ password: "Asks for your password", review: "Review what paru builds" })[root.request.kind]
                    || root.request.subject.trim().replace(/:$/, "")
                : root.runActive ? root.runStep : failed ? root.runLast : "",
            iconName: asking ? "bell" : root.runActive ? "loader" : failed ? "alert" : "check",
            tone: asking ? "warning" : failed ? "error" : ended ? "success" : "neutral",
            attention: asking,
            timed: root.runActive,
            actions: [{ id: "open", label: "Open" }]
        };
    }

    onRunActivityChanged: ActivityService.publish("system", root.runActivity)

    Connections {
        target: ActivityService

        function onActionRequested(provider, activityId, actionId) {
            if (provider === "system")
                root.open();
        }
    }

    // Edits wait their turn here, as engine arguments.
    property var pendingEdits: []

    function open() {
        if (root.shown)
            return;
        root.shown = true;
        root.runSeen = true;
        root.refresh();
        if (Date.now() - root.updatesCountedAt > 10 * 60 * 1000)
            root.refreshUpdates();
    }

    function close() {
        root.shown = false;
    }

    function toggle() {
        if (root.shown)
            root.close();
        else
            root.open();
    }

    function refresh() {
        if (!root.shown)
            return;
        if (statusProc.running)
            statusProc.again = true;
        else
            statusProc.start();
    }

    function refreshUpdates() {
        if (!updatesProc.running)
            updatesProc.running = true;
    }

    function setModule(id, on) {
        root.edit([on ? "enable" : "disable", id]);
    }

    function addPackage(name, moduleId) {
        root.edit(["add", moduleId, name]);
    }

    function removePackage(name) {
        root.edit(["remove", name]);
    }

    function adopt(target) {
        root.edit(["adopt", target]);
    }

    function restore(target) {
        root.edit(["restore", target]);
    }

    function init() {
        root.edit(["init"]);
    }

    function toggleRemoval(name) {
        root.removals = root.removals.includes(name)
            ? root.removals.filter(other => other !== name)
            : root.removals.concat([name]);
        root.refresh();
    }

    function apply() {
        root.start("apply", ["apply", "--yes"].concat(root.removalArgs()));
    }

    function update() {
        root.start("update", ["update", "--yes"]);
    }

    // Runs here, but with yay alone, which can't hand its review over, in a terminal.
    function start(kind, args) {
        if (root.running)
            return;
        if (root.status && root.status.helper === "yay") {
            root.runInTerminal(args);
            return;
        }
        root.runLog.clear();
        root.runKind = kind;
        root.runState = "running";
        root.runStep = "";
        root.runLast = "";
        root.runArgs = args;
        root.runToken = Math.random().toString(36).slice(2) + Date.now().toString(36);
        runProc.environment = { SPESHELL_WINDOW: root.runToken };
        runProc.command = [root.command].concat(args);
        runProc.running = true;
    }

    // The run's result seen: the window goes back to the machine.
    function dismissRun() {
        if (root.runActive)
            return;
        root.runKind = "";
        root.runState = "";
    }

    // The failed run again, in a terminal, for what only a person there can answer.
    function retryInTerminal() {
        root.dismissRun();
        root.runInTerminal(root.runArgs);
    }

    // From speshell-ask, over IPC: the run asks, to be answered on the FIFO ANSWER. Only
    // a FIFO speshell-ask made gets an answer, and only this run's ask a real one.
    function ask(token, answer, kind, subject) {
        if (!answer.startsWith(root.askDir) || !answer.endsWith("/answer"))
            return;
        if (token !== root.runToken || !root.runActive) {
            root.reply(answer, null);
            return;
        }
        if (kind === "password" && root.password !== "") {
            root.reply(answer, root.password);
            return;
        }
        root.requestError = "";
        root.reviewPackages = [];
        root.request = { answer: answer, kind: kind, subject: subject };
    }

    // Answers what the run asks: TEXT for a question, anything to build for a review.
    function respond(text) {
        const request = root.request;
        if (!request)
            return;
        if (request.kind === "password") {
            passwordCheck.check(text);
            return;
        }
        root.request = null;
        root.reply(request.answer, text);
    }

    // Declines what the run asks, which stops it.
    function decline() {
        const request = root.request;
        if (!request)
            return;
        root.request = null;
        root.reply(request.answer, null);
    }

    function reply(answer, text) {
        root.replies = root.replies.concat([{ answer: answer, line: text === null ? "-" : "+" + text }]);
        if (!replyProc.running)
            root.nextReply();
    }

    function nextReply() {
        if (root.replies.length === 0)
            return;
        const next = root.replies[0];
        root.replies = root.replies.slice(1);
        replyProc.line = next.line;
        replyProc.command = ["sh", "-c", "cat > \"$1\"", "speshell-reply", next.answer];
        replyProc.stdinEnabled = true;
        replyProc.running = true;
    }

    // A line of the run's output: without colors, the progress a carriage return
    // overwrote, or the questions the run answered with their defaults. A question ends
    // without a newline, so it comes in front of the next line on its stream, or alone
    // when the stream closes.
    function logLine(data) {
        const parts = data.replace(/\x1b\[[0-9;?]*[A-Za-z]/g, "")
            .replace(/^.*(\[[YyNn]\/[YyNn]\]|\(default=\d+\)):? */, "")
            .split("\r").filter(part => part.trim() !== "");
        if (parts.length === 0)
            return;
        const text = parts[parts.length - 1].replace(/\s+$/, "");
        const heading = text.startsWith("» ");
        if (heading)
            root.runStep = text.slice(2);
        else
            root.runLast = text;
        root.runLog.append({ text: heading ? text.slice(2) : text, kind: heading ? "heading" : "", note: "" });
        if (root.runLog.count > 3000)
            root.runLog.remove(0, root.runLog.count - 3000);
    }

    // Opens FILE of the modules' directory in your editor: a module's .conf, or one of its files.
    function openFile(file) {
        if (root.root !== "")
            Quickshell.execDetached(Shell.editFileCommand(root.root + "/" + file));
    }

    function search(query) {
        root.searchQuery = query.trim();
        if (root.searchQuery === "") {
            searchDelay.stop();
            root.repoResults = [];
            root.aurResults = [];
        } else {
            searchDelay.restart();
        }
    }

    function removalArgs() {
        return root.removals.reduce((args, name) => args.concat(["--remove", name]), []);
    }

    // Edits run one after another, and the status refreshes once they are done.
    function edit(args) {
        root.errorText = "";
        root.pendingEdits = root.pendingEdits.concat([args]);
        if (!editProc.running)
            root.nextEdit();
    }

    function nextEdit() {
        if (root.pendingEdits.length === 0) {
            root.refresh();
            return;
        }
        editProc.command = [root.command].concat(root.pendingEdits[0]);
        root.pendingEdits = root.pendingEdits.slice(1);
        editProc.running = true;
    }

    // The window steps aside, since it would cover the terminal.
    function runInTerminal(args) {
        if (root.running)
            return;
        terminalProc.command = Shell.terminalCommand([root.command].concat(args, ["--hold"]));
        terminalProc.running = true;
        root.close();
    }

    // After an apply or update, here or in a terminal.
    function ended() {
        root.removals = [];
        root.updatesCountedAt = 0;
        root.refresh();
        if (root.shown)
            root.refreshUpdates();
    }

    // The plan's steps by kind, in the order apply takes them: [{ kind, text, steps }].
    function groups(steps) {
        const order = ["disable", "leave", "unlinger", "demote", "remove", "install", "explicit",
            "link", "copy", "mode", "unlink", "delete", "trigger", "join", "linger", "enable", "run"];
        return order.map(kind => ({ kind: kind, steps: steps.filter(step => step.kind === kind) }))
            .filter(group => group.steps.length > 0)
            .map(group => Object.assign(group, { text: root.groupText(group.kind, group.steps.map(step => step.subject)) }));
    }

    function groupText(kind, subjects) {
        const named = subjects.length > 3 ? subjects.slice(0, 2).concat([(subjects.length - 2) + " more"]) : subjects;
        const names = named.length === 1 ? named[0] : named.slice(0, -1).join(", ") + " and " + named[named.length - 1];
        const count = word => subjects.length + " " + word + (subjects.length === 1 ? "" : "s");
        return ({
            disable: "Disable " + names,
            leave: "Leave " + names,
            unlinger: "Stop starting your services at boot",
            install: "Install " + names,
            explicit: "Mark " + names + " explicitly installed",
            demote: "Keep " + names + " as dependencies",
            remove: "Remove " + names,
            link: "Link " + count("file"),
            copy: "Copy " + count("file"),
            mode: "Fix the mode of " + count("file"),
            unlink: "Unlink " + count("file"),
            delete: "Delete " + count("file"),
            trigger: "Run " + count("command"),
            join: "Join " + names,
            linger: "Start your services at boot",
            enable: "Enable " + names,
            run: "Run " + names
        })[kind];
    }

    Process {
        id: statusProc

        property bool again: false

        function start() {
            statusProc.command = [root.command, "status", "--json"].concat(root.removalArgs());
            statusProc.running = true;
        }

        stdout: StdioCollector { id: statusOutput }
        stderr: StdioCollector { id: statusError }

        onExited: {
            try {
                root.status = JSON.parse(statusOutput.text);
                // A package declared since it was marked stays.
                root.removals = root.removals.filter(name => root.undeclared.includes(name));
            } catch (error) {
                root.errorText = statusError.text.trim() || "speshell system did not answer.";
            }
            if (statusProc.again) {
                statusProc.again = false;
                statusProc.start();
            }
        }
    }

    Process {
        id: editProc

        stderr: StdioCollector { id: editError }

        onExited: code => {
            if (code !== 0) {
                root.errorText = editError.text.trim().replace(/^speshell system: /, "");
                root.pendingEdits = [];
            }
            root.nextEdit();
        }
    }

    Process {
        id: terminalProc

        onExited: root.ended()
    }

    Process {
        id: runProc

        stdout: SplitParser { onRead: data => root.logLine(data) }
        stderr: SplitParser { onRead: data => root.logLine(data) }

        onExited: code => {
            root.runState = code === 0 ? "done" : "failed";
            root.runSeen = root.shown;
            // Whatever asked went with the run.
            root.request = null;
            root.password = "";
            root.ended();
        }
    }

    // sudo's password, tried before the run gets it, so a wrong one is asked again here.
    Process {
        id: passwordCheck

        property string candidate: ""

        function check(text) {
            passwordCheck.candidate = text;
            passwordCheck.stdinEnabled = true;
            passwordCheck.running = true;
        }

        command: ["sudo", "-S", "-k", "-v", "-p", ""]

        onStarted: {
            passwordCheck.write(passwordCheck.candidate + "\n");
            passwordCheck.stdinEnabled = false;
        }

        onExited: code => {
            const request = root.request;
            if (request && code === 0) {
                root.password = passwordCheck.candidate;
                root.request = null;
                root.reply(request.answer, passwordCheck.candidate);
            } else if (request) {
                root.requestError = "Wrong password, try again";
            }
            passwordCheck.candidate = "";
        }
    }

    // Writes an answer to speshell-ask's FIFO, through stdin, so no command line holds it.
    Process {
        id: replyProc

        property string line: ""

        onStarted: {
            replyProc.write(replyProc.line + "\n");
            replyProc.line = "";
            replyProc.stdinEnabled = false;
        }

        onExited: root.nextReply()
    }

    FileView {
        path: root.request && root.request.kind === "review" ? root.request.subject : ""
        printErrors: false
        onLoaded: {
            try {
                root.reviewPackages = JSON.parse(text());
            } catch (error) {
                root.reviewPackages = [];
            }
        }
    }

    Process {
        id: updatesProc

        command: [root.command, "updates"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const counts = JSON.parse(text);
                    root.updates = (counts.repo || 0) + (counts.aur || 0);
                    root.updatesCountedAt = Date.now();
                } catch (error) {
                    root.updates = -1;
                }
            }
        }
    }

    // Typing settles before a search starts; one still running takes the last query next.
    Timer {
        id: searchDelay
        interval: 250
        onTriggered: {
            if (!searchProc.running)
                searchProc.start();
        }
    }

    // A line for each source as it answers; those of a query since replaced are dropped.
    Process {
        id: searchProc

        property string query: ""

        function start() {
            searchProc.query = root.searchQuery;
            searchProc.command = [root.command, "search", root.searchQuery];
            searchProc.running = true;
        }

        stdout: SplitParser {
            onRead: data => {
                if (searchProc.query !== root.searchQuery)
                    return;
                try {
                    const answer = JSON.parse(data);
                    if (answer.source === "repos") {
                        root.repoResults = answer.packages;
                        root.aurResults = [];
                        root.aurPending = true;
                    } else {
                        root.aurResults = answer.packages;
                        root.aurPending = false;
                    }
                } catch (error) {}
            }
        }

        onExited: {
            if (searchProc.query === root.searchQuery)
                root.aurPending = false;
            else if (root.searchQuery !== "")
                searchProc.start();
        }
    }

    // Each module's .conf as edited elsewhere, watched while the window shows; the
    // window's own edits refresh on their own.
    Instantiator {
        model: root.shown && root.root !== "" ? root.modules.map(module => module.file) : []

        delegate: FileView {
            required property string modelData

            path: root.root + "/" + modelData
            watchChanges: true
            printErrors: false
            onFileChanged: changeDelay.restart()
        }
    }

    // An apply or update that ends elsewhere notes it here; one run from here ends on its own.
    FileView {
        path: root.shown ? root.statePath : ""
        watchChanges: true
        printErrors: false
        onFileChanged: {
            if (root.running)
                return;
            root.updatesCountedAt = 0;
            changeDelay.restart();
            root.refreshUpdates();
        }
    }

    Timer {
        id: changeDelay
        interval: 150
        onTriggered: root.refresh()
    }
}
