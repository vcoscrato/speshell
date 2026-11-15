pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "Shell.js" as Shell

// NetworkManager's VPN and WireGuard profiles. Connecting runs a conversation:
// whatever the login asks that nothing saved answers becomes a prompt on the
// row, and the answers that are credentials are saved in the Secret Service
// once the connection comes up.
//
// OpenConnect profiles log in here with openconnect --authenticate (username,
// password, gateway group, and the profile's form: entries), then hand
// NetworkManager the session cookie. Other profiles run nmcli --ask with the
// saved secrets as its passwd-file.
Singleton {
    id: root

    property var connections: [] // [{uuid, name, type, state}]
    readonly property bool active: root.connections.some(item => {
        return item.state === "activated";
    })

    // The profile this service is bringing up or down, or null: { uuid, kind: "connect"
    // or "disconnect" }.
    property var operation: null
    // What the login is asking: {uuid, kind: "login" | "question" | "choice",
    // message, label, masked, choices, user, needUser}.
    property var prompt: null
    property string errorUuid: ""
    property string errorText: ""
    // The failed attempt used saved secrets, so the row offers to type them again.
    property bool errorCanRetry: false

    // The running attempt; plain JS, nothing binds to it.
    property var session: null
    // A launch waiting for the previous attempt's process to exit.
    property var pendingLaunch: null

    readonly property var stateText: ({
        activating: "Connecting…",
        activated: "Connected",
        deactivating: "Disconnecting…"
    })

    function find(uuid) {
        for (let i = 0; i < root.connections.length; i++) {
            if (root.connections[i].uuid === uuid)
                return root.connections[i];
        }
        return null;
    }

    function promptFor(uuid) {
        return root.prompt && root.prompt.uuid === uuid ? root.prompt : null;
    }

    function subtitle(item) {
        const kind = item.type === "wireguard" ? "WireGuard" : "VPN";
        if (root.promptFor(item.uuid))
            return kind + " · Signing in";
        if (root.operatesOn(item.uuid) && (item.state === "" || item.state === "activated"))
            return kind + (root.operation.kind === "connect" ? " · Connecting…" : " · Disconnecting…");
        return kind + " · " + (root.stateText[item.state] || "Off");
    }

    function busy(item) {
        if (root.promptFor(item.uuid))
            return false;
        return root.operatesOn(item.uuid) || item.state === "activating" || item.state === "deactivating";
    }

    function operatesOn(uuid) {
        return root.operation !== null && root.operation.uuid === uuid;
    }

    function refresh() {
        if (!listProc.running)
            listProc.running = true;
    }

    // nmcli -t escapes ':' and '\' in values; NAME is last, so the first three
    // separators split the fixed fields.
    function parseList(text) {
        const result = [];
        const lines = String(text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const fields = lines[i].split(":");
            if (fields.length < 4 || (fields[1] !== "vpn" && fields[1] !== "wireguard"))
                continue;
            result.push({
                uuid: fields[0],
                type: fields[1],
                state: fields[2],
                name: fields.slice(3).join(":").replace(/\\(.)/g, "$1")
            });
        }
        return result.sort((a, b) => {
            return a.name.localeCompare(b.name);
        });
    }

    // vpn.data prints as "key = value, key = value".
    function parseVpnData(text) {
        const data = {};
        const items = String(text || "").split(/, (?=[^,=]+ = )/);
        for (let i = 0; i < items.length; i++) {
            const at = items[i].indexOf(" = ");
            if (at > 0)
                data[items[i].slice(0, at)] = items[i].slice(at + 3);
        }
        return data;
    }

    function connect(uuid, fresh) {
        if (root.operation)
            return;
        root.operation = { uuid: uuid, kind: "connect" };
        root.clearError();
        root.prompt = null;
        root.session = { uuid: uuid, fresh: !!fresh };
        prepareProc.command = Shell.script("vpn.sh", ["prepare", uuid]);
        prepareProc.running = true;
    }

    function disconnect(uuid) {
        if (root.operation)
            return;
        root.operation = { uuid: uuid, kind: "disconnect" };
        root.clearError();
        disconnectProc.command = ["nmcli", "connection", "down", "uuid", uuid];
        disconnectProc.running = true;
    }

    function clearError() {
        root.errorUuid = "";
        root.errorText = "";
        root.errorCanRetry = false;
    }

    function fail(text, canRetry) {
        root.errorUuid = root.session ? root.session.uuid : "";
        root.errorText = text;
        root.errorCanRetry = !!canRetry;
        root.finish();
    }

    function finish() {
        root.operation = null;
        root.prompt = null;
        root.session = null;
        root.refresh();
    }

    function cancel() {
        root.pendingLaunch = null;
        root.finish();
        sessionProc.running = false;
    }

    function launch(command, firstLine) {
        root.session.transcript = "";
        if (sessionProc.running) {
            root.pendingLaunch = { command: command, firstLine: firstLine };
            sessionProc.running = false;
            return;
        }
        sessionProc.command = command;
        sessionProc.firstLine = firstLine;
        sessionProc.running = true;
    }

    function finishPrepare(text) {
        const s = root.session;
        const info = {};
        const lines = String(text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const at = lines[i].indexOf("=");
            if (at > 0)
                info[lines[i].slice(0, at)] = lines[i].slice(at + 1);
        }
        if (/\.openconnect$/.test(info.service || "")) {
            const data = root.parseVpnData(info.data);
            s.openconnect = true;
            s.gateway = data.gateway || "";
            s.protocol = data.protocol || "anyconnect";
            s.formEntries = [];
            for (const key in data) {
                const match = /^form:([^:]+):(.+)$/.exec(key);
                if (match)
                    s.formEntries.push(match[1] + ":" + match[2] + "=" + data[key]);
            }
            s.user = info.savedUser || info.user || "";
            s.savedUser = info.savedUser || "";
            s.authgroup = info.savedAuthgroup || "";
            s.password = "";
            if (s.user === "" || info.savedPassword !== "yes" || s.fresh)
                root.askLogin("");
            else
                root.startOpenconnect();
        } else {
            s.openconnect = false;
            s.usedSaved = Number(info.savedFields) > 0 && !s.fresh;
            root.startNmcli();
        }
    }

    // live: openconnect is waiting at the rejected form for a new password.
    function askLogin(message, live) {
        const s = root.session;
        root.prompt = {
            uuid: s.uuid,
            kind: "login",
            message: message,
            live: !!live,
            user: s.user,
            needUser: s.user === "" || message !== ""
        };
    }

    function submitLogin(user, password) {
        const s = root.session;
        const asked = root.prompt;
        if (!s || !asked || asked.kind !== "login" || password === "" || (asked.needUser && user === ""))
            return;
        root.prompt = null;
        s.password = password;
        if (asked.live && (!asked.needUser || user === s.user)) {
            root.reply(password);
            return;
        }
        if (asked.needUser)
            s.user = user;
        root.startOpenconnect();
    }

    function startOpenconnect() {
        const s = root.session;
        root.launch(Shell.script("vpn.sh", ["openconnect", s.uuid, s.protocol, s.gateway, s.user, s.authgroup]
            .concat(s.formEntries)), s.password);
    }

    function startNmcli() {
        const s = root.session;
        s.answers = {};
        root.launch(Shell.script("vpn.sh", ["nmcli", s.uuid, s.fresh ? "1" : "0"]), null);
    }

    // Codes, tokens, and challenge answers change every login.
    function oneTime(text) {
        return /otp|token|challenge|code|pin\b/i.test(text);
    }

    // Output arrives in chunks. A prompt is an unterminated line ending in ':'
    // after which the program goes quiet.
    function read(chunk) {
        const s = root.session;
        if (!s || root.pendingLaunch)
            return;
        s.transcript += chunk;
        if (/:\s?$/.test(s.transcript.slice(s.transcript.lastIndexOf("\n") + 1)))
            promptDelay.restart();
        else
            promptDelay.stop();
    }

    function promptReady() {
        const s = root.session;
        if (!s || !sessionProc.running)
            return;
        const lastBreak = s.transcript.lastIndexOf("\n");
        const tail = s.transcript.slice(lastBreak + 1);
        const lines = s.transcript.slice(0, Math.max(0, lastBreak)).split("\n");
        const message = lines.length > 0 ? lines[lines.length - 1].trim() : "";
        if (s.openconnect)
            root.openconnectPrompt(tail, message, lines);
        else
            root.nmcliPrompt(tail, message);
    }

    function openconnectPrompt(tail, message, lines) {
        const s = root.session;
        if (/SAML|single sign-on/i.test(s.transcript)) {
            root.stopForError("This VPN signs in through a web browser, which Speshell can't do.");
            return;
        }
        const choice = /^(.*?)\s*\[(.*)\]:\s?$/.exec(tail);
        if (choice) {
            root.prompt = {
                uuid: s.uuid,
                kind: "choice",
                message: message,
                label: choice[1].replace(/:$/, ""),
                choices: choice[2].split("|")
            };
            return;
        }
        // The login form came back: the server rejected the credentials.
        if (message !== "" && lines.indexOf(message) < lines.length - 1) {
            root.askLogin("The username or password was rejected.", true);
            return;
        }
        root.prompt = {
            uuid: s.uuid,
            kind: "question",
            message: message,
            label: tail.trim().replace(/:$/, ""),
            masked: false
        };
    }

    function nmcliPrompt(tail, message) {
        const s = root.session;
        const match = /^(.*) \(([^()\s]+)\): $/.exec(tail);
        const label = match ? match[1] : tail.trim().replace(/:$/, "");
        s.field = match ? match[2] : "";
        root.prompt = {
            uuid: s.uuid,
            kind: "question",
            message: message,
            label: label,
            masked: !root.oneTime(label + " " + s.field)
        };
    }

    function answer(text) {
        const s = root.session;
        if (!s || !root.prompt || root.prompt.kind === "login")
            return;
        if (root.prompt.kind === "choice")
            s.authgroup = text;
        else if (!s.openconnect && s.field.indexOf(".") > 0 && !root.oneTime(root.prompt.label + " " + s.field))
            s.answers[s.field] = text;
        root.prompt = null;
        root.reply(text);
    }

    // Answers the waiting prompt; its line leaves the transcript so the next
    // prompt's message is real output.
    function reply(text) {
        const s = root.session;
        s.transcript = s.transcript.slice(0, s.transcript.lastIndexOf("\n") + 1);
        sessionProc.write(text + "\n");
    }

    function stopForError(text) {
        root.fail(text, false);
        sessionProc.running = false;
    }

    function lastLine(text) {
        const lines = String(text || "").trim().split("\n").filter(line => {
            return line !== "***" && line.indexOf("Failed to complete authentication") === -1
                && line.indexOf("User input required") === -1;
        });
        return lines.length > 0 ? lines[lines.length - 1].replace(/^Error: /, "").trim() : "";
    }

    function finishSession(exitCode) {
        const s = root.session;
        if (!s)
            return;
        if (exitCode === 0) {
            root.save(s);
            root.finish();
            return;
        }
        if (s.openconnect && /failed verification/.test(s.transcript))
            root.fail("The VPN server's certificate isn't trusted.", false);
        else
            root.fail(root.lastLine(s.transcript) || "Could not connect.", !s.openconnect && s.usedSaved);
    }

    // Writes the credentials this login used to the Secret Service.
    function save(s) {
        let fields = {};
        if (s.openconnect) {
            if (s.password !== "")
                fields.password = s.password;
            if (s.user !== s.savedUser)
                fields.user = s.user;
            if (s.authgroup !== "")
                fields.authgroup = s.authgroup;
        } else {
            fields = s.answers;
        }
        let input = "";
        for (const field in fields)
            input += field + "\n" + fields[field] + "\n";
        if (input === "")
            return;
        const item = root.find(s.uuid);
        storeProc.input = input;
        storeProc.command = Shell.script("vpn.sh", ["store", s.uuid, item ? item.name : "VPN"]);
        storeProc.running = true;
    }

    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "UUID,TYPE,STATE,NAME", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: root.connections = root.parseList(text)
        }
    }

    // Any NetworkManager change can add, remove, or switch a profile.
    Process {
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: refreshDebounce.restart()
        }
    }

    Timer {
        id: refreshDebounce
        interval: 200
        onTriggered: root.refresh()
    }

    Process {
        id: prepareProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.session && root.operation)
                    root.finishPrepare(text);
            }
        }
    }

    Timer {
        id: promptDelay
        interval: 150
        onTriggered: root.promptReady()
    }

    // The scripts send everything to stdout, so prompts arrive in order.
    Process {
        id: sessionProc
        property var firstLine: null
        stdinEnabled: true
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => root.read(data)
        }
        onStarted: {
            if (sessionProc.firstLine !== null)
                sessionProc.write(sessionProc.firstLine + "\n");
            sessionProc.firstLine = null;
        }
        onExited: exitCode => {
            const next = root.pendingLaunch;
            root.pendingLaunch = null;
            if (next) {
                sessionProc.command = next.command;
                sessionProc.firstLine = next.firstLine;
                sessionProc.running = true;
                return;
            }
            root.finishSession(exitCode);
        }
    }

    Process {
        id: storeProc
        property string input: ""
        stdinEnabled: true
        onStarted: {
            storeProc.write(storeProc.input);
            storeProc.input = "";
            storeProc.stdinEnabled = false;
        }
        onExited: storeProc.stdinEnabled = true
    }

    Process {
        id: disconnectProc
        stderr: StdioCollector { id: disconnectErr }
        onExited: exitCode => {
            const uuid = root.operation ? root.operation.uuid : "";
            root.operation = null;
            if (exitCode !== 0) {
                root.errorUuid = uuid;
                root.errorText = root.lastLine(disconnectErr.text) || "Could not disconnect.";
            }
            root.refresh();
        }
    }

    Component.onCompleted: root.refresh()
}
