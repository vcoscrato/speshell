pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import "CalendarEvents.js" as CalendarEvents

// Your calendars, through Dux Calendar's daemon (dcal): it signs in to Google and the
// others, keeps them synced, and sends their reminders as notifications. Speshell
// talks to it over its socket, starting it when it isn't running, for the events of
// the month the clock panel shows and to add, change, and delete them.
Singleton {
    id: root

    readonly property bool installed: FeatureSupport.hasCommand("dcal")
    // "absent" (dcal isn't installed), "starting", "ready", or "failed" (it won't start).
    property string status: "absent"
    readonly property bool ready: root.status === "ready"

    property var accounts: []
    // By id: { id, name, account, color, readOnly, hidden, self }
    property var calendars: ({})
    readonly property var writableCalendars: Object.keys(root.calendars).map(id => root.calendars[id])
        .filter(calendar => !calendar.readOnly && !calendar.hidden)
    readonly property bool signedIn: root.accounts.length > 0
    // An account that can't sync until you act: { id, kind, signIn, message }, or null;
    // `signIn` when signing in again is the fix, rather than unlocking the keyring.
    readonly property var accountProblem: {
        for (const account of root.accounts) {
            if (account.keyringLocked)
                return { id: account.id, kind: account.kind, signIn: false, message: "Unlock your keyring so " + account.displayName + " can sync." };
            if (account.needsReauth || account.authError)
                return { id: account.id, kind: account.kind, signIn: true, message: account.displayName + " needs you to sign in again." };
        }
        return null;
    }

    // The events by local day (yyyy-MM-dd), for the days being watched.
    property var days: ({})
    property bool loaded: false
    // When a sync last finished, as Speshell saw it; 0 before the first.
    property double syncedAt: 0
    property bool syncing: false
    // A sign-in waiting on the browser, by its flow's state.
    property string signInState: ""
    property string signInError: ""

    // What the clock panel shows: the month, and the picked day, which may be in another.
    property bool watching: false
    property date month: new Date()
    property date day: new Date()

    property int lastId: 0
    property var pending: ({})
    property int launches: 0
    property int searches: 0
    property int generation: 0

    // A calendar without a color of its own takes one of the theme's, in the order dcal lists them.
    readonly property var palette: [Theme.blue, Theme.peach, Theme.teal, Theme.pink, Theme.yellow, Theme.success]

    function color(event) {
        if (event.color !== "")
            return event.color;
        const index = Object.keys(root.calendars).indexOf(event.calendarId);
        return index < 0 ? Theme.accent : root.palette[index % root.palette.length];
    }

    function eventsOn(date) {
        return root.days[CalendarEvents.dateKey(date)] || [];
    }

    function connect() {
        if (!root.installed || root.ready || finder.running || socket.connected)
            return;
        root.status = "starting";
        finder.running = true;
    }

    // A live daemon's socket, or none: then start one, and look again while it comes up.
    function found(path) {
        if (path !== "") {
            root.searches = 0;
            socket.path = path;
            socket.connected = true;
            return;
        }
        if (root.launches < 3 && root.searches === 0) {
            root.launches++;
            Quickshell.execDetached(["dcal", "daemon"]);
        }
        if (++root.searches <= 10) {
            retry.interval = 500;
            retry.restart();
        } else {
            root.searches = 0;
            root.status = "failed";
        }
    }

    function request(method, params, done) {
        if (!socket.connected) {
            if (done)
                done(null, "Dux Calendar isn't running.");
            return;
        }
        const id = ++root.lastId;
        if (done)
            root.pending[id] = done;
        socket.write(JSON.stringify({ id: id, method: method, params: params || {} }) + "\n");
        socket.flush();
    }

    function receive(line) {
        let message;
        try {
            message = JSON.parse(line);
        } catch (error) {
            return;
        }
        if (message.event) {
            root.notice(message.event, message.data || {});
            return;
        }
        const done = root.pending[message.id];
        if (!done)
            return;
        delete root.pending[message.id];
        done(message.error ? null : message.result, message.error ? root.plain(message.error) : "");
    }

    // "ErrNotFound: event not found" reads as "Event not found".
    function plain(error) {
        const text = String(error).replace(/^Err[A-Za-z]+:\s*/, "");
        return text.charAt(0).toUpperCase() + text.substring(1);
    }

    function notice(topic, data) {
        if (topic === "events")
            reload.restart();
        else if (topic === "calendars" || topic === "accounts")
            root.loadAccounts();
        else if (topic === "sync" && data.type === "completed") {
            root.syncedAt = Date.now();
            root.syncing = false;
        }
    }

    function loadAccounts() {
        root.request("accounts.list", {}, (result, error) => {
            if (error === "")
                root.accounts = result || [];
        });
        root.request("calendars.list", {}, (result, error) => {
            if (error !== "")
                return;
            root.calendars = CalendarEvents.calendarsById(result);
            root.loadEvents();
        });
    }

    function loadEvents() {
        if (!root.ready)
            return;
        if (!root.watching) {
            root.loaded = false;
            return;
        }
        const first = new Date(root.month.getFullYear(), root.month.getMonth(), 1);
        const next = new Date(root.month.getFullYear(), root.month.getMonth() + 1, 1);
        const day = new Date(root.day.getFullYear(), root.day.getMonth(), root.day.getDate());
        const from = day < first ? day : first;
        const to = day >= next ? new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1) : next;
        const generation = ++root.generation;
        root.request("events.list", { from: CalendarEvents.rfc3339(from), to: CalendarEvents.rfc3339(to) }, (result, error) => {
            if (generation !== root.generation || error !== "")
                return;
            root.days = CalendarEvents.byDay(CalendarEvents.events(result.events, root.calendars));
            root.loaded = true;
        });
    }

    function refresh() {
        root.syncing = true;
        syncTimeout.restart();
        root.request("accounts.refresh", {}, (result, error) => {
            if (error !== "")
                root.syncing = false;
        });
    }

    // Saves the form's draft as a new event, or over `event`. A repeating event's
    // changes reach every occurrence, its times moved by as much as this one's.
    function save(event, draft, done) {
        const params = CalendarEvents.params(draft);
        if (params.error) {
            done(params.error);
            return;
        }
        if (event) {
            delete params.calendarId;
            params.id = event.id;
            if (event.recurring)
                params.occurrenceStart = event.occurrence;
        }
        root.request(event ? "events.update" : "events.create", params, (result, error) => {
            if (error === "")
                root.loadEvents();
            done(error);
        });
    }

    // Deletes `event`, or only this occurrence of a repeating one.
    function remove(event, onlyThis, done) {
        const params = { id: event.id };
        if (event.recurring && onlyThis)
            params.occurrenceStart = event.occurrence;
        root.request("events.delete", params, (result, error) => {
            if (error === "")
                root.loadEvents();
            done(error);
        });
    }

    // Opens Google's sign-in in the browser, for a new account or `accountId`'s again,
    // and waits for it there.
    function signIn(accountId) {
        root.signInError = "";
        const method = accountId ? "accounts.google.reauth" : "accounts.google.start";
        root.request(method, accountId ? { accountId: accountId } : {}, (result, error) => {
            if (error !== "") {
                root.signInError = error;
                return;
            }
            root.signInState = result.state;
            Qt.openUrlExternally(result.authUrl);
            flow.connected = false;
            flow.path = socket.path;
            flow.connected = true;
        });
    }

    function cancelSignIn() {
        if (root.signInState !== "")
            root.request("accounts.google.cancel", { state: root.signInState });
        root.signInState = "";
        flow.connected = false;
    }

    // Opening the panel tries again a daemon that wouldn't start.
    onWatchingChanged: {
        if (root.watching && root.status === "failed")
            root.connect();
        root.loadEvents();
    }
    onMonthChanged: reload.restart()
    onDayChanged: reload.restart()
    onInstalledChanged: root.connect()
    Component.onCompleted: root.connect()

    // dcal names its socket after its process, which leaves the socket of one that
    // crashed behind: only a live one counts. DANKCAL_SOCKET names it outright.
    Process {
        id: finder
        command: ["sh", "-c", "[ -n \"$DANKCAL_SOCKET\" ] && { echo \"$DANKCAL_SOCKET\"; exit; }; "
            + "for s in \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}\"/dankcal-*.sock; do "
            + "p=${s##*-}; p=${p%.sock}; [ -S \"$s\" ] && kill -0 \"$p\" 2>/dev/null && { echo \"$s\"; exit; }; done"]
        stdout: StdioCollector { id: finderOutput }
        onExited: root.found(finderOutput.text.trim())
    }

    Timer {
        id: retry
        onTriggered: finder.running = true
    }

    Timer {
        id: reload
        interval: 150
        onTriggered: root.loadEvents()
    }

    Timer {
        id: syncTimeout
        interval: 60000
        onTriggered: root.syncing = false
    }

    Socket {
        id: socket

        onConnectionStateChanged: {
            if (socket.connected) {
                root.status = "ready";
                root.launches = 0;
                root.request("subscribe", { topics: ["accounts", "calendars", "events", "sync"] });
                root.loadAccounts();
                return;
            }
            for (const id in root.pending)
                root.pending[id](null, "Dux Calendar stopped.");
            root.pending = {};
            root.loaded = false;
            root.status = "starting";
            retry.interval = 2000;
            retry.restart();
        }
        onError: {
            if (!socket.connected) {
                retry.interval = 2000;
                retry.restart();
            }
        }

        parser: SplitParser {
            onRead: line => root.receive(line)
        }
    }

    // A sign-in waits here, on its own connection, for up to the five minutes dcal gives it.
    Socket {
        id: flow

        onConnectionStateChanged: {
            if (flow.connected && root.signInState !== "")
                flow.write(JSON.stringify({ id: 1, method: "accounts.google.complete", params: { state: root.signInState } }) + "\n");
            flow.flush();
        }

        parser: SplitParser {
            onRead: line => {
                let message;
                try {
                    message = JSON.parse(line);
                } catch (error) {
                    return;
                }
                if (message.id !== 1)
                    return;
                if (message.error && root.signInState !== "")
                    root.signInError = "Google sign-in didn't finish: " + root.plain(message.error);
                root.signInState = "";
                flow.connected = false;
                root.loadAccounts();
            }
        }
    }
}
