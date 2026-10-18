pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

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
    readonly property bool active: root.connections.some(function(item) {
        return item.state === "activated";
    })

    // The profile being brought up or down by this service.
    property string busyUuid: ""
    property bool busyConnecting: false
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
        for (var i = 0; i < root.connections.length; i++) {
            if (root.connections[i].uuid === uuid)
                return root.connections[i];
        }
        return null;
    }

    function promptFor(uuid) {
        return root.prompt && root.prompt.uuid === uuid ? root.prompt : null;
    }

    function subtitle(item) {
        var kind = item.type === "wireguard" ? "WireGuard" : "VPN";
        if (root.promptFor(item.uuid))
            return kind + " · Signing in";
        if (root.busyUuid === item.uuid && (item.state === "" || item.state === "activated"))
            return kind + (root.busyConnecting ? " · Connecting…" : " · Disconnecting…");
        return kind + " · " + (root.stateText[item.state] || "Off");
    }

    function busy(item) {
        if (root.promptFor(item.uuid))
            return false;
        return root.busyUuid === item.uuid || item.state === "activating" || item.state === "deactivating";
    }

    function refresh() {
        if (!listProc.running)
            listProc.running = true;
    }

    // nmcli -t escapes ':' and '\' in values; NAME is last, so the first three
    // separators split the fixed fields.
    function parseList(text) {
        var result = [];
        var lines = String(text || "").split("\n");
        for (var i = 0; i < lines.length; i++) {
            var fields = lines[i].split(":");
            if (fields.length < 4 || (fields[1] !== "vpn" && fields[1] !== "wireguard"))
                continue;
            result.push({
                uuid: fields[0],
                type: fields[1],
                state: fields[2],
                name: fields.slice(3).join(":").replace(/\\(.)/g, "$1")
            });
        }
        return result.sort(function(a, b) {
            return a.name.localeCompare(b.name);
        });
    }

    // vpn.data prints as "key = value, key = value".
    function parseVpnData(text) {
        var data = {};
        var items = String(text || "").split(/, (?=[^,=]+ = )/);
        for (var i = 0; i < items.length; i++) {
            var at = items[i].indexOf(" = ");
            if (at > 0)
                data[items[i].slice(0, at)] = items[i].slice(at + 3);
        }
        return data;
    }

    function connect(uuid, fresh) {
        if (root.busyUuid !== "")
            return;
        root.busyUuid = uuid;
        root.busyConnecting = true;
        root.clearError();
        root.prompt = null;
        root.session = { uuid: uuid, fresh: !!fresh };
        prepareProc.command = ["bash", "-c", root.prepareScript, "speshell-vpn", uuid];
        prepareProc.running = true;
    }

    function disconnect(uuid) {
        if (root.busyUuid !== "")
            return;
        root.busyUuid = uuid;
        root.busyConnecting = false;
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
        root.busyUuid = "";
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
        var s = root.session;
        var info = {};
        var lines = String(text || "").split("\n");
        for (var i = 0; i < lines.length; i++) {
            var at = lines[i].indexOf("=");
            if (at > 0)
                info[lines[i].slice(0, at)] = lines[i].slice(at + 1);
        }
        if (/\.openconnect$/.test(info.service || "")) {
            var data = root.parseVpnData(info.data);
            s.openconnect = true;
            s.gateway = data.gateway || "";
            s.protocol = data.protocol || "anyconnect";
            s.formEntries = [];
            for (var key in data) {
                var match = /^form:([^:]+):(.+)$/.exec(key);
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
        var s = root.session;
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
        var s = root.session;
        var asked = root.prompt;
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
        var s = root.session;
        root.launch(["bash", "-c", root.openconnectScript, "speshell-vpn",
                     s.uuid, s.protocol, s.gateway, s.user, s.authgroup].concat(s.formEntries), s.password);
    }

    function startNmcli() {
        var s = root.session;
        s.answers = {};
        root.launch(["bash", "-c", root.nmcliScript, "speshell-vpn", s.uuid, s.fresh ? "1" : "0"], null);
    }

    // Codes, tokens, and challenge answers change every login.
    function oneTime(text) {
        return /otp|token|challenge|code|pin\b/i.test(text);
    }

    // Output arrives in chunks. A prompt is an unterminated line ending in ':'
    // after which the program goes quiet.
    function read(chunk) {
        var s = root.session;
        if (!s || root.pendingLaunch)
            return;
        s.transcript += chunk;
        if (/:\s?$/.test(s.transcript.slice(s.transcript.lastIndexOf("\n") + 1)))
            promptDelay.restart();
        else
            promptDelay.stop();
    }

    function promptReady() {
        var s = root.session;
        if (!s || !sessionProc.running)
            return;
        var lastBreak = s.transcript.lastIndexOf("\n");
        var tail = s.transcript.slice(lastBreak + 1);
        var lines = s.transcript.slice(0, Math.max(0, lastBreak)).split("\n");
        var message = lines.length > 0 ? lines[lines.length - 1].trim() : "";
        if (s.openconnect)
            root.openconnectPrompt(tail, message, lines);
        else
            root.nmcliPrompt(tail, message);
    }

    function openconnectPrompt(tail, message, lines) {
        var s = root.session;
        if (/SAML|single sign-on/i.test(s.transcript)) {
            root.stopForError("This VPN signs in through a web browser, which Speshell can't do.");
            return;
        }
        var choice = /^(.*?)\s*\[(.*)\]:\s?$/.exec(tail);
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
        var s = root.session;
        var match = /^(.*) \(([^()\s]+)\): $/.exec(tail);
        var label = match ? match[1] : tail.trim().replace(/:$/, "");
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
        var s = root.session;
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
        var s = root.session;
        s.transcript = s.transcript.slice(0, s.transcript.lastIndexOf("\n") + 1);
        sessionProc.write(text + "\n");
    }

    function stopForError(text) {
        root.fail(text, false);
        sessionProc.running = false;
    }

    function lastLine(text) {
        var lines = String(text || "").trim().split("\n").filter(function(line) {
            return line !== "***" && line.indexOf("Failed to complete authentication") === -1
                && line.indexOf("User input required") === -1;
        });
        return lines.length > 0 ? lines[lines.length - 1].replace(/^Error: /, "").trim() : "";
    }

    function finishSession(exitCode) {
        var s = root.session;
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
        var fields = {};
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
        var input = "";
        for (var field in fields)
            input += field + "\n" + fields[field] + "\n";
        if (input === "")
            return;
        var item = root.find(s.uuid);
        storeProc.input = input;
        storeProc.command = ["bash", "-c", root.storeScript, "speshell-vpn", s.uuid, item ? item.name : "VPN"];
        storeProc.running = true;
    }

    // Prints what connecting needs to know, one key=value per line.
    readonly property string prepareScript: "uuid=$1\n"
        + "show() { nmcli -e no -g \"$1\" connection show uuid \"$uuid\" 2>/dev/null; }\n"
        + "saved() { secret-tool lookup speshell-vpn \"$uuid\" field \"$1\" 2>/dev/null; }\n"
        + "echo \"service=$(show vpn.service-type)\"\n"
        + "echo \"data=$(show vpn.data)\"\n"
        + "echo \"user=$(show vpn.user-name)\"\n"
        + "echo \"savedUser=$(saved user)\"\n"
        + "echo \"savedAuthgroup=$(saved authgroup)\"\n"
        + "saved password >/dev/null && echo savedPassword=yes\n"
        + "echo \"savedFields=$(secret-tool search --all speshell-vpn \"$uuid\" 2>/dev/null | grep -c '^label = .* · .*\\..*')\"\n"

    // Args: uuid protocol gateway user authgroup form-entries…; stdin's first line
    // is a typed password (empty: the saved one), and later lines answer prompts.
    readonly property string openconnectScript: "exec 2>&1\n"
        + "uuid=$1 protocol=$2 gateway=$3 user=$4 group=$5\n"
        + "shift 5\n"
        + "args=(--protocol=\"$protocol\")\n"
        + "[ -z \"$user\" ] || args+=(--user=\"$user\")\n"
        + "[ -z \"$group\" ] || args+=(--authgroup=\"$group\")\n"
        + "for entry; do args+=(--form-entry=\"$entry\"); done\n"
        + "IFS= read -r password\n"
        + "[ -n \"$password\" ] || password=$(secret-tool lookup speshell-vpn \"$uuid\" field password)\n"
        + "exec 3< <(printf '%s\\n' \"$password\"; exec cat)\n"
        + "feeder=$!\n"
        + "login=$(openconnect --authenticate --non-inter --passwd-on-stdin \"${args[@]}\" \"$gateway\" <&3)\n"
        + "status=$?\n"
        + "exec 3<&-\n"
        + "kill \"$feeder\" 2>/dev/null\n"
        + "[ \"$status\" -eq 0 ] || exit 1\n"
        + "COOKIE= HOST= CONNECT_URL= FINGERPRINT= RESOLVE=\n"
        + "eval \"$login\"\n"
        + "{ printf 'vpn.secrets.cookie:%s\\n' \"$COOKIE\"\n"
        + "  printf 'vpn.secrets.gateway:%s\\n' \"${CONNECT_URL:-$HOST}\"\n"
        + "  printf 'vpn.secrets.gwcert:%s\\n' \"$FINGERPRINT\"\n"
        + "  [ -z \"$RESOLVE\" ] || printf 'vpn.secrets.resolve:%s\\n' \"$RESOLVE\"\n"
        + "} | nmcli connection up uuid \"$uuid\" passwd-file /dev/stdin\n"

    // Args: uuid fresh. Saved secrets are labelled "<name> VPN · <setting.key>";
    // nmcli asks for anything they don't cover.
    readonly property string nmcliScript: "uuid=$1\n"
        + "saved=\n"
        + "[ \"$2\" = 1 ] || saved=$(secret-tool search --all speshell-vpn \"$uuid\" 2>/dev/null | awk '\n"
        + "  /^label = / { n = split($0, part, \" · \"); field = n > 1 ? part[n] : \"\" }\n"
        + "  /^secret = / && field ~ /\\./ { print field \":\" substr($0, 10) }')\n"
        + "nmcli --ask connection up uuid \"$uuid\" passwd-file <(printf '%s\\n' \"$saved\") 2>&1\n"

    // Args: uuid name; stdin holds field and value lines in pairs.
    readonly property string storeScript: "uuid=$1 name=$2\n"
        + "while IFS= read -r field && IFS= read -r value; do\n"
        + "  printf '%s' \"$value\" | secret-tool store --label=\"$name VPN · $field\" speshell-vpn \"$uuid\" field \"$field\"\n"
        + "done\n"

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
                if (root.session && root.busyUuid !== "")
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
        onExited: function(exitCode) {
            var next = root.pendingLaunch;
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
        onExited: function(exitCode) {
            var uuid = root.busyUuid;
            root.busyUuid = "";
            if (exitCode !== 0) {
                root.errorUuid = uuid;
                root.errorText = root.lastLine(disconnectErr.text) || "Could not disconnect.";
            }
            root.refresh();
        }
    }

    Component.onCompleted: root.refresh()
}
