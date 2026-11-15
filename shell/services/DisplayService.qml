pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "Shell.js" as Shell

// Hyprland's monitors for the Displays panel: a draft of modes, positions, and layout
// that applies on request and reverts unless kept. LidService turns the laptop's own
// display off and on with the lid.
Singleton {
    id: root

    // Each display as monitor() reads it from hyprctl: { name, description, disabled,
    // focused, width and height in pixels, scale, x and y in logical pixels, mirrorOf
    // (the name of the display it mirrors, or ""), mode (its mode's key, or "preferred"),
    // and modes (the keys of the ones it has, largest first) }.
    property var monitors: []
    // The displays as the panel edits them, until applied.
    property var draftMonitors: []
    // What the draft changes; "" when there is no draft.
    property string pendingSummary: ""
    property string selectedName: ""
    // "idle"; "applying" the draft, then "confirming" it until kept or reverted;
    // "layout", applying Mirror or Extend, which needs no confirming; "interrupted", when
    // a display came or went while confirming, so the next read reverts; or "reverting",
    // after either, or after a change that failed partway.
    property string phase: "idle"
    property int confirmationSecondsRemaining: 0
    // The displays before the change being applied or confirmed, or before a revert
    // that failed.
    property var rollbackMonitors: []
    // Why the displays are being put back: the change that failed partway, shown once
    // they are; "" when the revert is the user's or the countdown's.
    property string revertReason: ""
    // Until then, displays coming and going are the change being applied.
    property double topologyEventGraceUntil: 0
    // Why the last change or revert failed, until the next; and why the last read did.
    property string changeError: ""
    property string readError: ""
    readonly property string errorText: root.changeError || root.readError
    // Set by the launcher, so the outcome shows on the OSD rather than in a closed panel.
    property bool announceLayout: false

    readonly property bool loading: monitorsProc.running
    readonly property bool busy: root.phase !== "idle" || root.loading
    readonly property bool hasPending: root.pendingSummary !== ""
    readonly property bool canRetryRevert: root.phase === "idle" && root.rollbackMonitors.length > 0
    readonly property var draftActiveMonitors: root.draftMonitors.filter(monitor => !monitor.disabled)
    readonly property string draftLayoutMode: root.layoutOf(root.draftMonitors)
    readonly property string layoutMode: root.layoutOf(root.monitors)
    readonly property var selectedMonitor: root.draftMonitors.find(monitor => monitor.name === root.selectedName) || null
    // Mirroring needs a second display, on or off.
    readonly property bool canMirror: root.monitors.length > 1
    readonly property bool mirrored: root.layoutMode === "mirror"

    // ── Modes ──────────────────────────────────────────────
    // A mode as hyprctl writes it, "2560x1440@165.00Hz", as { width, height,
    // refreshRate }; null when it isn't one.
    function parseMode(text) {
        const match = String(text).trim().match(/^(\d+)x(\d+)@([\d.]+)\s*(Hz)?$/i);
        if (!match)
            return null;
        const mode = { width: Number(match[1]), height: Number(match[2]), refreshRate: Number(match[3]) };
        return mode.width > 0 && mode.height > 0 && mode.refreshRate > 0 ? mode : null;
    }

    // A mode's key, "2560x1440@165.00", as hyprctl takes it.
    function modeKey(mode) {
        return mode.width + "x" + mode.height + "@" + mode.refreshRate.toFixed(2);
    }

    // A mode key as the panel shows it, "2560x1440@165Hz", with the refresh rate's
    // decimals only when it has them.
    function modeLabel(key) {
        const mode = root.parseMode(key);
        if (!mode)
            return "Preferred";
        const rounded = Math.round(mode.refreshRate);
        const refresh = Math.abs(mode.refreshRate - rounded) < 0.01 ? rounded : mode.refreshRate.toFixed(2);
        return mode.width + "x" + mode.height + "@" + refresh + "Hz";
    }

    // ── Displays ───────────────────────────────────────────
    // A display from `hyprctl monitors -j`; `names` maps ids to names, since Hyprland
    // names the display another mirrors by its id.
    function monitor(raw, names) {
        const current = raw.width > 0 && raw.height > 0 && raw.refreshRate > 0
            ? { width: raw.width, height: raw.height, refreshRate: raw.refreshRate }
            : null;
        const modes = (raw.availableModes || []).map(root.parseMode).filter(mode => mode !== null)
            .concat(current ? [current] : [])
            .sort((a, b) => b.width - a.width || b.height - a.height || b.refreshRate - a.refreshRate)
            .map(root.modeKey);
        return {
            name: String(raw.name || ""),
            description: String(raw.description || ""),
            disabled: !!raw.disabled,
            focused: !!raw.focused,
            width: Number(raw.width) || 1,
            height: Number(raw.height) || 1,
            scale: Number(raw.scale) > 0 ? Number(raw.scale) : 1,
            x: Number(raw.x) || 0,
            y: Number(raw.y) || 0,
            mirrorOf: names[String(raw.mirrorOf)] || "",
            mode: current ? root.modeKey(current) : "preferred",
            modes: modes.filter((key, index) => modes.indexOf(key) === index)
        };
    }

    // The ones on first, then by name.
    function sorted(monitors) {
        return monitors.slice().sort((a, b) => (a.disabled - b.disabled) || a.name.localeCompare(b.name));
    }

    function isInternal(monitor) {
        return /^(eDP|LVDS|DSI)-/.test(monitor.name);
    }

    function logicalWidth(monitor) {
        return Math.max(1, Math.round(monitor.width / monitor.scale));
    }

    function logicalHeight(monitor) {
        return Math.max(1, Math.round(monitor.height / monitor.scale));
    }

    // The area `monitors` cover.
    function boundsOf(monitors) {
        if (monitors.length === 0)
            return { minX: 0, minY: 0, maxX: 1, maxY: 1, width: 1, height: 1 };
        const minX = Math.min(...monitors.map(monitor => monitor.x));
        const minY = Math.min(...monitors.map(monitor => monitor.y));
        const maxX = Math.max(...monitors.map(monitor => monitor.x + root.logicalWidth(monitor)));
        const maxY = Math.max(...monitors.map(monitor => monitor.y + root.logicalHeight(monitor)));
        return { minX: minX, minY: minY, maxX: maxX, maxY: maxY, width: Math.max(1, maxX - minX), height: Math.max(1, maxY - minY) };
    }

    // "single" with one display on; "mirror" when one mirrors another or two share a
    // place; "extend" otherwise.
    function layoutOf(monitors) {
        const active = monitors.filter(monitor => !monitor.disabled);
        if (active.length <= 1)
            return "single";
        const places = active.map(monitor => Math.round(monitor.x) + "x" + Math.round(monitor.y));
        const shared = places.some((place, index) => places.indexOf(place) !== index);
        return shared || active.some(monitor => monitor.mirrorOf !== "") ? "mirror" : "extend";
    }

    // The display on that the selected one is placed against, or null.
    function anchorFor(monitor) {
        return root.draftActiveMonitors.find(other => other.name !== monitor.name) || null;
    }

    // ── The draft ──────────────────────────────────────────
    function ensureSelected() {
        if (root.selectedMonitor)
            return;
        const active = root.draftActiveMonitors;
        const primary = active.find(monitor => monitor.focused) || active[0] || root.draftMonitors[0];
        root.selectedName = primary ? primary.name : "";
    }

    function setSelected(name) {
        if (root.draftMonitors.some(monitor => monitor.name === name))
            root.selectedName = name;
    }

    function resetDraft() {
        root.draftMonitors = root.monitors;
        root.pendingSummary = "";
        root.ensureSelected();
    }

    // Drafts `summary`: `change` gets a copy of each display, to change and return.
    function draft(summary, change) {
        root.draftMonitors = root.sorted(root.draftMonitors.map(monitor => change(Object.assign({}, monitor))));
        root.pendingSummary = summary;
        root.ensureSelected();
    }

    function setSelectedEnabled(enabled) {
        const selected = root.selectedMonitor;
        if (!selected || (!enabled && root.draftActiveMonitors.length <= 1))
            return;
        const bounds = root.boundsOf(root.draftActiveMonitors);
        root.draft((enabled ? "Enable " : "Turn off ") + selected.name, monitor => {
            if (monitor.name === selected.name) {
                monitor.disabled = !enabled;
                monitor.mirrorOf = "";
                if (enabled) {
                    monitor.x = bounds.maxX;
                    monitor.y = bounds.minY;
                }
            }
            return monitor;
        });
    }

    function setSelectedMode(key) {
        const selected = root.selectedMonitor;
        const mode = root.parseMode(key);
        if (!selected || selected.disabled || !mode)
            return;
        root.draft("Set " + selected.name + " to " + root.modeLabel(key), monitor => {
            if (monitor.name === selected.name) {
                monitor.mode = root.modeKey(mode);
                monitor.width = mode.width;
                monitor.height = mode.height;
            }
            return monitor;
        });
    }

    // Places the selected display left, right, above, or below its anchor.
    function arrangeSelected(edge) {
        const selected = root.selectedMonitor;
        const anchor = selected ? root.anchorFor(selected) : null;
        if (!anchor)
            return;
        const offsets = {
            left: [-root.logicalWidth(selected), 0],
            right: [root.logicalWidth(anchor), 0],
            above: [0, -root.logicalHeight(selected)],
            below: [0, root.logicalHeight(anchor)]
        };
        const offset = offsets[edge] || offsets.right;
        root.draft("Place " + selected.name + " " + edge + " of " + anchor.name, monitor => {
            if (monitor.name === anchor.name || monitor.name === selected.name) {
                const placed = monitor.name === selected.name;
                monitor.disabled = false;
                monitor.mirrorOf = "";
                monitor.x = placed ? offset[0] : 0;
                monitor.y = placed ? offset[1] : 0;
            }
            return monitor;
        });
    }

    // Drafts a layout around the selected display: "single" turns the others off,
    // "mirror" has them mirror it, and "extend" lines them up to its right.
    function draftLayout(mode) {
        const selected = root.selectedMonitor;
        if (!selected)
            return;
        let nextX = root.logicalWidth(selected);
        const summaries = { single: "Use only " + selected.name, mirror: "Mirror displays", extend: "Extend displays" };
        root.draft(summaries[mode], monitor => {
            const own = monitor.name === selected.name;
            monitor.disabled = mode === "single" && !own;
            monitor.mirrorOf = mode === "mirror" && !own ? selected.name : "";
            if (own || mode !== "extend") {
                if (!monitor.disabled) {
                    monitor.x = 0;
                    monitor.y = 0;
                }
            } else {
                monitor.x = nextX;
                monitor.y = 0;
                nextX += root.logicalWidth(monitor);
            }
            return monitor;
        });
    }

    // ── Applying ───────────────────────────────────────────
    // The hyprctl arguments that set `monitor` up: an `eval` of Lua under a Lua config,
    // else a `keyword monitor` rule.
    function commandFor(monitor) {
        const mirrored = monitor.mirrorOf !== "";
        const position = mirrored ? "0x0" : Math.round(monitor.x) + "x" + Math.round(monitor.y);
        if (!HyprlandService.usingLua) {
            const rule = monitor.disabled
                ? [monitor.name, "disable"]
                : [monitor.name, monitor.mode, position, monitor.scale].concat(mirrored ? ["mirror", monitor.mirrorOf] : []);
            return ["keyword", "monitor", rule.join(",")];
        }
        const quote = HyprlandService.luaQuote;
        if (monitor.disabled)
            return ["eval", "hl.monitor({ output = " + quote(monitor.name) + ", disabled = true })"];
        return ["eval", "hl.monitor({ output = " + quote(monitor.name)
            + ", mode = " + quote(monitor.mode)
            + ", position = " + quote(position)
            + ", scale = " + monitor.scale
            // Always sent: Hyprland merges the rule into the last one, so a mirror left
            // out stays mirrored, and a display disabled before (as the lid does) stays
            // disabled.
            + ", mirror = " + quote(monitor.mirrorOf)
            + ", disabled = false"
            + " })"];
    }

    // Sets `monitors` up, in `phase` until done. Stops at the first display Hyprland
    // refuses, so the ones before it may have changed.
    function run(monitors, phase) {
        if (applyProc.running || monitors.length === 0)
            return false;
        const commands = monitors.reduce((args, monitor) => args.concat(root.commandFor(monitor), "--"), []);
        applyProc.command = Shell.script("display.sh", commands);
        applyProc.running = true;
        root.phase = phase;
        root.changeError = "";
        return true;
    }

    function applyDraft() {
        if (!root.hasPending || root.busy)
            return;
        root.rollbackMonitors = root.monitors;
        if (!root.run(root.draftMonitors, "applying")) {
            root.rollbackMonitors = [];
            root.resetDraft();
        }
    }

    function keepDisplayChanges() {
        if (root.phase !== "confirming")
            return;
        confirmationTimer.stop();
        root.phase = "idle";
        root.rollbackMonitors = [];
        root.changeError = "";
        root.refresh();
    }

    // Back to rollbackMonitors, those of them still connected.
    function revertDisplayChanges() {
        if (root.rollbackMonitors.length === 0 || applyProc.running)
            return false;
        confirmationTimer.stop();
        const connected = root.rollbackMonitors.filter(monitor => root.monitors.some(other => other.name === monitor.name));
        if (root.run(connected, "reverting"))
            return true;
        root.phase = "idle";
        root.changeError = "Could not start display rollback.";
        return false;
    }

    // Mirror and Extend apply at once around the selected display, dropping any draft:
    // every display stays on and the source keeps its place, so there is nothing to
    // confirm. Single turns displays off, so it is drafted for Apply and Keep instead.
    function setLayout(mode) {
        if (mode === "single") {
            root.draftLayout(mode);
            return true;
        }
        if (root.busy || !root.canMirror)
            return false;
        root.resetDraft();
        root.draftLayout(mode);
        root.rollbackMonitors = root.monitors;
        if (root.run(root.draftMonitors, "layout"))
            return true;
        root.rollbackMonitors = [];
        root.resetDraft();
        return false;
    }

    // Mirrors every display onto the focused one, or extends them again.
    function toggleMirror() {
        root.resetDraft();
        root.setSelected(HyprlandService.focusedMonitor);
        root.announceLayout = root.setLayout(root.mirrored ? "extend" : "mirror");
        if (!root.announceLayout)
            OsdService.show("display", "Displays unchanged", root.busy ? "Another change is in progress" : "");
    }

    function finishApply(exitCode, errors) {
        const failure = exitCode !== 0 ? errors.trim() || "Display change failed." : "";
        const phase = root.phase;
        root.phase = "idle";
        if (phase === "reverting") {
            if (failure !== "") {
                root.changeError = errors.trim() || "Display rollback failed.";
            } else {
                root.rollbackMonitors = [];
                root.changeError = root.revertReason;
                root.revertReason = "";
            }
        } else if (phase === "layout") {
            if (root.announceLayout)
                OsdService.show("display", failure !== "" ? "Display change failed"
                    : root.draftLayoutMode === "mirror" ? "Displays mirrored" : "Displays extended", failure);
            root.announceLayout = false;
            root.pendingSummary = "";
            if (failure !== "")
                root.undoFailed(failure);
            else
                root.rollbackMonitors = [];
        } else if (failure !== "") {
            // The draft stays, to fix and apply again.
            root.undoFailed(failure);
        } else {
            root.pendingSummary = "";
            root.phase = "confirming";
            root.confirmationSecondsRemaining = 15;
            root.topologyEventGraceUntil = Date.now() + 1500;
            confirmationTimer.restart();
        }
        root.refresh();
    }

    // Puts every display back after a change Hyprland refused partway.
    function undoFailed(failure) {
        root.revertReason = failure;
        if (!root.revertDisplayChanges())
            root.changeError = failure;
    }

    // ── Reading ────────────────────────────────────────────
    function refresh() {
        if (HyprlandService.running && !monitorsProc.running)
            monitorsProc.running = true;
    }

    function queueRefresh() {
        if (!root.hasPending && !root.busy)
            refreshDebounce.restart();
    }

    function finishRead(exitCode, output, errors) {
        let raw = null;
        try {
            raw = JSON.parse(output || "[]");
        } catch (error) {
            console.warn("[Speshell] Failed to parse hyprctl monitors output:", error);
        }
        if (Array.isArray(raw)) {
            const names = {};
            raw.forEach(monitor => names[String(monitor.id)] = String(monitor.name || ""));
            root.monitors = root.sorted(raw.map(monitor => root.monitor(monitor, names)));
            if (root.hasPending)
                root.ensureSelected();
            else
                root.resetDraft();
            root.readError = exitCode !== 0 ? errors.trim() || "Could not read displays." : "";
        } else {
            root.readError = "Could not read displays.";
        }
        if (root.phase === "interrupted")
            Qt.callLater(root.revertDisplayChanges);
    }

    // Read once at start, so the launcher knows whether !mirror applies.
    Component.onCompleted: root.refresh()

    Timer {
        id: refreshDebounce
        interval: 250
        onTriggered: root.refresh()
    }

    Timer {
        id: confirmationTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.confirmationSecondsRemaining--;
            if (root.confirmationSecondsRemaining <= 0)
                root.revertDisplayChanges();
        }
    }

    Connections {
        target: HyprlandService

        function onEvent(name) {
            if (name !== "monitoradded" && name !== "monitoraddedv2" && name !== "monitorremoved")
                return;
            HyprlandService.refreshMonitors();
            if (root.phase === "confirming" && Date.now() >= root.topologyEventGraceUntil) {
                confirmationTimer.stop();
                root.phase = "interrupted";
                root.refresh();
            } else {
                root.queueRefresh();
            }
        }
    }

    Process {
        id: monitorsProc
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector { id: monitorsOutput }
        stderr: StdioCollector { id: monitorsErrors }
        onExited: exitCode => root.finishRead(exitCode, monitorsOutput.text, monitorsErrors.text)
    }

    Process {
        id: applyProc
        stderr: StdioCollector { id: applyErrors }
        onExited: exitCode => root.finishApply(exitCode, applyErrors.text)
    }
}
