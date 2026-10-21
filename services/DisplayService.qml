pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "Shell.js" as Shell

// Hyprland's monitors for the Displays panel: a draft of modes, positions, and layout
// that applies on request and reverts unless kept. With the lid closed and another
// display on, the laptop's own display turns off until the lid opens.
Singleton {
    id: root

    // ── State ──────────────────────────────────────────────
    property var monitors: []
    property var draftMonitors: []
    property bool applying: false
    property bool confirming: false
    property bool reverting: false
    property bool loading: false
    property bool hasPending: false
    property string errorText: ""
    property string pendingSummary: ""
    property string selectedName: ""
    property int confirmationSecondsRemaining: 0
    property var rollbackMonitors: []
    property bool rollbackRetryAvailable: false
    property string operationKind: ""
    property bool topologyRollbackQueued: false
    property double topologyEventGraceUntil: 0

    readonly property bool displayEditingLocked: root.applying
        || root.loading
        || root.confirming
        || root.reverting

    readonly property var draftActiveMonitors: root.buildActiveMonitors(root.draftMonitors)
    readonly property string draftLayoutMode: root.detectLayoutMode(root.draftMonitors)
    // Mirroring needs a second display, on or off.
    readonly property bool canMirror: root.monitors.length > 1
    readonly property bool mirrored: root.detectLayoutMode(root.monitors) === "mirror"
    property bool mirrorQueued: false
    // The laptop's display as it was before the closed lid turned it off, or null.
    property var lidParkedMonitor: null

    function monitorName(monitor) {
        return monitor && monitor.name ? String(monitor.name) : "";
    }

    function monitorScale(monitor) {
        var scale = monitor && monitor.scale !== undefined ? Number(monitor.scale) : 1;
        return scale > 0 ? scale : 1;
    }

    function formatModeRefresh(refreshRate) {
        var refresh = Number(refreshRate) || 0;
        return refresh > 0 ? refresh.toFixed(2) : "";
    }

    function normalizeMode(mode) {
        var raw = String(mode || "").trim();
        if (raw === "")
            return "";
        var parsed = root.parseMode(raw);
        if (!parsed)
            return raw;
        return parsed.width + "x" + parsed.height + "@" + root.formatModeRefresh(parsed.refreshRate) + "Hz";
    }

    function parseMode(mode) {
        var match = String(mode || "").trim().match(/^([0-9]+)x([0-9]+)@([0-9.]+)\s*(Hz)?$/i);
        if (!match)
            return null;
        var width = parseInt(match[1], 10);
        var height = parseInt(match[2], 10);
        var refreshRate = Number(match[3]) || 0;
        if (width <= 0 || height <= 0 || refreshRate <= 0)
            return null;
        return { width: width, height: height, refreshRate: refreshRate };
    }

    function modeLabel(mode) {
        var parsed = root.parseMode(mode);
        if (!parsed)
            return String(mode || "Preferred");
        var rounded = Math.round(parsed.refreshRate);
        var refresh = Math.abs(parsed.refreshRate - rounded) < 0.01
            ? String(rounded)
            : parsed.refreshRate.toFixed(2);
        return parsed.width + "x" + parsed.height + "@" + refresh + "Hz";
    }

    function modeCommand(mode) {
        var normalized = root.normalizeMode(mode);
        return normalized === "" ? "preferred" : normalized.replace(/Hz$/i, "");
    }

    function monitorModeString(monitor) {
        if (monitor && monitor.mode)
            return root.normalizeMode(monitor.mode);
        var width = Number(monitor && monitor.width) || 0;
        var height = Number(monitor && monitor.height) || 0;
        var refresh = Number(monitor && monitor.refreshRate) || 0;
        if (width <= 0 || height <= 0 || refresh <= 0)
            return "preferred";
        return width + "x" + height + "@" + root.formatModeRefresh(refresh) + "Hz";
    }

    function availableModesFor(monitor) {
        var result = [];
        var seen = {};
        var rawModes = monitor && monitor.availableModes ? monitor.availableModes : [];

        for (var i = 0; i < rawModes.length; i++) {
            var mode = root.normalizeMode(rawModes[i]);
            if (mode !== "" && !seen[mode]) {
                seen[mode] = true;
                result.push(mode);
            }
        }

        var current = root.monitorModeString(monitor);
        if (current !== "" && current !== "preferred" && !seen[current]) {
            result.push(current);
        }

        result.sort(function(a, b) {
            var left = root.parseMode(a);
            var right = root.parseMode(b);
            if (!left || !right) {
                return String(a).localeCompare(String(b));
            }
            if (left.width !== right.width) {
                return right.width - left.width;
            }
            if (left.height !== right.height) {
                return right.height - left.height;
            }
            return right.refreshRate - left.refreshRate;
        });
        return result;
    }

    function modesEquivalent(left, right) {
        return root.normalizeMode(left) === root.normalizeMode(right);
    }

    function logicalWidth(monitor) {
        return Math.max(1, Math.round((Number(monitor && monitor.width) || 1) / root.monitorScale(monitor)));
    }

    function logicalHeight(monitor) {
        return Math.max(1, Math.round((Number(monitor && monitor.height) || 1) / root.monitorScale(monitor)));
    }

    function buildActiveMonitors(source) {
        return (source || []).filter(function(monitor) { return monitor && !monitor.disabled; });
    }

    function primaryMonitorObject(source) {
        var active = root.buildActiveMonitors(source);
        if (active.length === 0)
            return source.length > 0 ? source[0] : null;

        for (var i = 0; i < active.length; i++) {
            if (active[i].focused) {
                return active[i];
            }
        }

        return active[0];
    }

    // Mirrored when a display mirrors another or two share a position.
    function detectMirrored(source) {
        var active = root.buildActiveMonitors(source);
        var occupiedPositions = {};
        for (var i = 0; i < active.length; i++) {
            var mirrorOf = String(active[i].mirrorOf || "");
            if (mirrorOf !== "" && mirrorOf !== "none")
                return true;
            var positionKey = Math.round(Number(active[i].x) || 0)
                + "x" + Math.round(Number(active[i].y) || 0);
            if (occupiedPositions[positionKey])
                return true;
            occupiedPositions[positionKey] = true;
        }
        return false;
    }

    function detectLayoutMode(source) {
        if (root.buildActiveMonitors(source).length <= 1)
            return "single";
        return root.detectMirrored(source) ? "mirror" : "extend";
    }

    function cloneMonitor(monitor) {
        return {
            name: root.monitorName(monitor),
            description: monitor && monitor.description ? String(monitor.description) : "",
            disabled: !!(monitor && monitor.disabled),
            focused: !!(monitor && monitor.focused),
            width: Number(monitor && monitor.width) || 1,
            height: Number(monitor && monitor.height) || 1,
            refreshRate: Number(monitor && monitor.refreshRate) || 0,
            mode: root.monitorModeString(monitor),
            availableModes: root.availableModesFor(monitor),
            scale: root.monitorScale(monitor),
            x: Number(monitor && monitor.x) || 0,
            y: Number(monitor && monitor.y) || 0,
            mirrorOf: String((monitor && monitor.mirrorOf) || "")
        };
    }

    function cloneMonitors(source) {
        var result = [];
        var list = source || [];
        for (var i = 0; i < list.length; i++) {
            result.push(root.cloneMonitor(list[i]));
        }
        return result;
    }

    function sortMonitors(source) {
        var result = root.cloneMonitors(source);
        result.sort(function(a, b) {
            if (!!a.disabled !== !!b.disabled) {
                return a.disabled ? 1 : -1;
            }
            return root.monitorName(a).localeCompare(root.monitorName(b));
        });
        return result;
    }

    function monitorByName(source, name) {
        var list = source || [];
        var targetName = String(name || "");
        for (var i = 0; i < list.length; i++) {
            if (root.monitorName(list[i]) === targetName) {
                return list[i];
            }
        }
        return null;
    }

    function selectedDraftMonitor() {
        return root.monitorByName(root.draftMonitors, root.selectedName);
    }

    function ensureSelected() {
        if (root.selectedDraftMonitor())
            return;

        var primary = root.primaryMonitorObject(root.draftMonitors);
        root.selectedName = primary ? root.monitorName(primary) : "";
    }

    function setSelected(name) {
        if (root.monitorByName(root.draftMonitors, name)) {
            root.selectedName = String(name || "");
        }
    }

    function resetDraft() {
        root.draftMonitors = root.cloneMonitors(root.monitors);
        root.hasPending = false;
        root.pendingSummary = "";
        root.ensureSelected();
    }

    function markPending(summary, nextDraft) {
        root.draftMonitors = root.sortMonitors(nextDraft);
        root.hasPending = true;
        root.pendingSummary = summary;
        root.ensureSelected();
    }

    // The hyprctl arguments that apply a draft monitor: an `eval` of Lua under a Lua
    // config, else a `keyword monitor` rule.
    function commandForDraftMonitor(monitor) {
        const name = root.monitorName(monitor);
        if (name === "")
            return [];
        const mirrorTarget = String(monitor.mirrorOf || "");
        const mirrored = mirrorTarget !== "" && mirrorTarget !== "none";
        const mode = root.modeCommand(root.monitorModeString(monitor));
        const position = mirrored
            ? "0x0"
            : Math.round(Number(monitor.x) || 0) + "x" + Math.round(Number(monitor.y) || 0);
        const scale = root.monitorScale(monitor);
        if (!HyprlandService.usingLua) {
            const rule = monitor.disabled
                ? [name, "disable"]
                : [name, mode, position, scale].concat(mirrored ? ["mirror", mirrorTarget] : []);
            return ["keyword", "monitor", rule.join(",")];
        }
        const quote = HyprlandService.luaQuote;
        if (monitor.disabled)
            return ["eval", "hl.monitor({ output = " + quote(name) + ", disabled = true })"];
        return ["eval", "hl.monitor({ output = " + quote(name)
            + ", mode = " + quote(mode)
            + ", position = " + quote(position)
            + ", scale = " + scale
            + (mirrorTarget !== "" ? ", mirror = " + quote(mirrorTarget) : "")
            + " })"];
    }

    // With connectedOnly, monitors unplugged since `source` was read are skipped.
    function commandsForMonitors(source, connectedOnly) {
        var connected = root.monitors.map(root.monitorName);
        return (source || []).filter(function(monitor) {
            return !connectedOnly || connected.indexOf(root.monitorName(monitor)) >= 0;
        }).map(root.commandForDraftMonitor);
    }

    function runMonitorCommands(commands, operation) {
        if (applyProc.running) {
            return false;
        }

        const lines = commands.filter(args => args.length > 0)
            .map(args => "hyprctl " + args.map(Shell.quote).join(" "));
        if (lines.length === 0)
            return false;
        const script = "set -e\n" + lines.join("\n") + "\n";

        applyProc.command = ["sh", "-c", script];
        applyProc.running = true;
        root.applying = true;
        root.operationKind = operation || "apply";
        root.errorText = "";
        return true;
    }

    function applyDraft() {
        if (!root.hasPending || root.displayEditingLocked) {
            return;
        }

        root.rollbackMonitors = root.cloneMonitors(root.monitors);
        root.rollbackRetryAvailable = false;
        if (!root.runMonitorCommands(root.commandsForMonitors(root.draftMonitors, false), "apply")) {
            root.rollbackMonitors = [];
            root.resetDraft();
        }
    }

    function keepDisplayChanges() {
        if (!root.confirming)
            return;
        confirmationTimer.stop();
        root.confirming = false;
        root.confirmationSecondsRemaining = 0;
        root.rollbackMonitors = [];
        root.rollbackRetryAvailable = false;
        root.errorText = "";
        root.refresh();
    }

    function revertDisplayChanges() {
        if (root.rollbackMonitors.length === 0 || applyProc.running)
            return false;

        confirmationTimer.stop();
        root.confirming = false;
        root.confirmationSecondsRemaining = 0;
        root.reverting = true;
        root.rollbackRetryAvailable = false;
        var commands = root.commandsForMonitors(root.rollbackMonitors, true);
        if (!root.runMonitorCommands(commands, "rollback")) {
            root.reverting = false;
            root.rollbackRetryAvailable = true;
            root.errorText = "Could not start display rollback.";
            return false;
        }
        return true;
    }

    // Mirrors every display onto the focused one, or extends them again if they are
    // mirrored. It reads the displays first, then applies like the Displays panel does,
    // so the change waits for Keep there and reverts on its own otherwise.
    function toggleMirror() {
        root.mirrorQueued = true;
        root.refresh();
    }

    function runQueuedMirror() {
        root.mirrorQueued = false;
        if (root.applying || root.confirming || root.reverting)
            return;
        if (!root.canMirror) {
            root.errorText = "Mirroring needs a second display.";
            return;
        }
        root.resetDraft();
        var source = root.primaryMonitorObject(root.draftMonitors);
        if (source)
            root.selectedName = root.monitorName(source);
        root.setDraftLayoutMode(root.mirrored ? "extend" : "mirror");
        root.applyDraft();
    }

    function activeDraftCount() {
        return root.buildActiveMonitors(root.draftMonitors).length;
    }

    function firstOtherActiveDraftMonitor(name) {
        var active = root.buildActiveMonitors(root.draftMonitors);
        var selected = String(name || "");
        for (var i = 0; i < active.length; i++) {
            if (root.monitorName(active[i]) !== selected) {
                return active[i];
            }
        }
        return null;
    }

    function setSelectedEnabled(enabled) {
        var selected = root.selectedDraftMonitor();
        if (!selected) {
            return;
        }
        if (!enabled && root.activeDraftCount() <= 1) {
            return;
        }

        var next = [];
        for (var i = 0; i < root.draftMonitors.length; i++) {
            var monitor = root.cloneMonitor(root.draftMonitors[i]);
            if (root.monitorName(monitor) === root.monitorName(selected)) {
                monitor.disabled = !enabled;
                monitor.mirrorOf = "";
                if (enabled) {
                    var bounds = root.boundsFor(root.buildActiveMonitors(root.draftMonitors));
                    monitor.x = bounds.maxX;
                    monitor.y = bounds.minY;
                }
            }
            next.push(monitor);
        }
        root.markPending((enabled ? "Enable " : "Turn off ") + root.monitorName(selected), next);
    }

    function setSelectedMode(mode) {
        var selected = root.selectedDraftMonitor();
        if (!selected || selected.disabled) {
            return;
        }

        var normalized = root.normalizeMode(mode);
        var parsed = root.parseMode(normalized);
        if (!parsed) {
            return;
        }

        var next = [];
        for (var i = 0; i < root.draftMonitors.length; i++) {
            var monitor = root.cloneMonitor(root.draftMonitors[i]);
            if (root.monitorName(monitor) === root.monitorName(selected)) {
                monitor.mode = normalized;
                monitor.width = parsed.width;
                monitor.height = parsed.height;
                monitor.refreshRate = parsed.refreshRate;
            }
            next.push(monitor);
        }
        root.markPending("Set " + root.monitorName(selected) + " to " + root.modeLabel(normalized), next);
    }

    function arrangeSelected(edge) {
        var selected = root.selectedDraftMonitor();
        if (!selected) {
            return;
        }
        var anchor = root.firstOtherActiveDraftMonitor(root.monitorName(selected));
        if (!anchor) {
            return;
        }

        var selectedName = root.monitorName(selected);
        var anchorName = root.monitorName(anchor);
        var next = [];
        var selectedWidth = root.logicalWidth(selected);
        var selectedHeight = root.logicalHeight(selected);
        var anchorWidth = root.logicalWidth(anchor);
        var anchorHeight = root.logicalHeight(anchor);

        for (var i = 0; i < root.draftMonitors.length; i++) {
            var monitor = root.cloneMonitor(root.draftMonitors[i]);
            if (root.monitorName(monitor) === anchorName) {
                monitor.disabled = false;
                monitor.x = 0;
                monitor.y = 0;
                monitor.mirrorOf = "";
            } else if (root.monitorName(monitor) === selectedName) {
                monitor.disabled = false;
                monitor.mirrorOf = "";
                if (edge === "left") {
                    monitor.x = -selectedWidth;
                    monitor.y = 0;
                } else if (edge === "above") {
                    monitor.x = 0;
                    monitor.y = -selectedHeight;
                } else if (edge === "below") {
                    monitor.x = 0;
                    monitor.y = anchorHeight;
                } else {
                    monitor.x = anchorWidth;
                    monitor.y = 0;
                }
            }
            next.push(monitor);
        }
        root.markPending("Place " + selectedName + " " + edge + " of " + anchorName, next);
    }

    function useOnlySelected() {
        var selected = root.selectedDraftMonitor();
        if (!selected) {
            return;
        }

        var selectedName = root.monitorName(selected);
        var next = [];
        for (var i = 0; i < root.draftMonitors.length; i++) {
            var monitor = root.cloneMonitor(root.draftMonitors[i]);
            monitor.disabled = root.monitorName(monitor) !== selectedName;
            if (!monitor.disabled) {
                monitor.x = 0;
                monitor.y = 0;
                monitor.mirrorOf = "";
            }
            next.push(monitor);
        }
        root.markPending("Use only " + selectedName, next);
    }

    function setDraftLayoutMode(mode) {
        var selected = root.selectedDraftMonitor();
        if (!selected) {
            return;
        }

        var selectedName = root.monitorName(selected);
        var nextMode = String(mode || "");
        if (nextMode === "single") {
            root.useOnlySelected();
            return;
        }

        var next = [];
        var offsetX = root.logicalWidth(selected);
        for (var i = 0; i < root.draftMonitors.length; i++) {
            var monitor = root.cloneMonitor(root.draftMonitors[i]);
            var name = root.monitorName(monitor);
            monitor.disabled = false;

            if (name === selectedName) {
                monitor.x = 0;
                monitor.y = 0;
                monitor.mirrorOf = "";
            } else if (nextMode === "mirror") {
                monitor.x = 0;
                monitor.y = 0;
                monitor.mirrorOf = selectedName;
            } else {
                monitor.x = offsetX;
                monitor.y = 0;
                monitor.mirrorOf = "";
                offsetX += root.logicalWidth(monitor);
            }

            next.push(monitor);
        }

        root.markPending(nextMode === "mirror" ? "Mirror displays" : "Extend displays", next);
    }

    function boundsFor(source) {
        var active = root.buildActiveMonitors(source);
        if (active.length === 0) {
            return { minX: 0, minY: 0, maxX: 1, maxY: 1, width: 1, height: 1 };
        }

        var minX = Number(active[0].x) || 0;
        var minY = Number(active[0].y) || 0;
        var maxX = minX + root.logicalWidth(active[0]);
        var maxY = minY + root.logicalHeight(active[0]);

        for (var i = 1; i < active.length; i++) {
            var monitor = active[i];
            var x = Number(monitor.x) || 0;
            var y = Number(monitor.y) || 0;
            minX = Math.min(minX, x);
            minY = Math.min(minY, y);
            maxX = Math.max(maxX, x + root.logicalWidth(monitor));
            maxY = Math.max(maxY, y + root.logicalHeight(monitor));
        }

        return {
            minX: minX,
            minY: minY,
            maxX: maxX,
            maxY: maxY,
            width: Math.max(1, maxX - minX),
            height: Math.max(1, maxY - minY)
        };
    }

    function mapRect(monitor, canvasWidth, canvasHeight) {
        if (!monitor || monitor.disabled) {
            return { x: 0, y: 0, width: 0, height: 0 };
        }

        var padding = 10;
        var availableWidth = Math.max(1, canvasWidth - padding * 2);
        var availableHeight = Math.max(1, canvasHeight - padding * 2);
        var active = root.buildActiveMonitors(root.draftMonitors);

        if (root.detectLayoutMode(root.draftMonitors) === "mirror" && active.length > 1) {
            var index = Math.max(0, active.map(root.monitorName).indexOf(root.monitorName(monitor)));
            var slotWidth = availableWidth / active.length;
            var mirrorScale = Math.min(
                Math.max(1, slotWidth - 6) / root.logicalWidth(monitor),
                availableHeight / root.logicalHeight(monitor)
            );
            var mirrorWidth = Math.max(34, root.logicalWidth(monitor) * mirrorScale);
            var mirrorHeight = Math.max(24, root.logicalHeight(monitor) * mirrorScale);
            return {
                x: padding + index * slotWidth + Math.max(0, (slotWidth - mirrorWidth) / 2),
                y: padding + Math.max(0, (availableHeight - mirrorHeight) / 2),
                width: mirrorWidth,
                height: mirrorHeight
            };
        }

        var bounds = root.boundsFor(root.draftMonitors);
        var scale = Math.min(availableWidth / bounds.width, availableHeight / bounds.height);
        var width = Math.max(34, root.logicalWidth(monitor) * scale);
        var height = Math.max(24, root.logicalHeight(monitor) * scale);
        return {
            x: padding + ((Number(monitor.x) || 0) - bounds.minX) * scale,
            y: padding + ((Number(monitor.y) || 0) - bounds.minY) * scale,
            width: width,
            height: height
        };
    }

    // ── The lid ────────────────────────────────────────────
    function isInternal(monitor) {
        return /^(eDP|LVDS|DSI)-/.test(root.monitorName(monitor));
    }

    // Turns the laptop's display off while the lid is closed and another display is
    // on, and back on as it was once the lid opens or the last other display goes.
    // Waits while a change in the Displays panel awaits Keep.
    function followLid() {
        if (!HyprlandService.running || root.displayEditingLocked || root.hasPending)
            return;
        const internal = root.monitors.find(monitor => root.isInternal(monitor) && !monitor.disabled);
        const othersOn = root.monitors.some(monitor => !root.isInternal(monitor) && !monitor.disabled);
        if (SessionService.lidClosed && internal && othersOn && !root.lidParkedMonitor) {
            root.lidParkedMonitor = root.cloneMonitor(internal);
            root.runLidCommand(root.commandForDraftMonitor(Object.assign(root.cloneMonitor(internal), { disabled: true })));
        } else if (root.lidParkedMonitor && (!SessionService.lidClosed || !othersOn)) {
            const parked = root.lidParkedMonitor;
            root.lidParkedMonitor = null;
            root.runLidCommand(root.commandForDraftMonitor(parked));
        }
    }

    function runLidCommand(args) {
        if (args.length === 0)
            return;
        Quickshell.execDetached(["hyprctl"].concat(args));
        refreshDebounce.restart();
    }

    Connections {
        target: SessionService

        function onLidClosedChanged() { root.refresh(); }
    }

    // ── Actions ────────────────────────────────────────────
    function refresh() {
        if (HyprlandService.running && !monitorsProc.running) {
            root.loading = true;
            monitorsProc.running = true;
        }
    }

    function queueRefresh() {
        if (!root.hasPending && !root.applying && !root.loading) {
            refreshDebounce.restart();
        }
    }

    // Read once at start, so the launcher knows whether !mirror applies.
    Component.onCompleted: root.refresh()

    Timer {
        id: refreshDebounce
        interval: 250
        repeat: false
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
            if (name === "monitoradded" || name === "monitoraddedv2" || name === "monitorremoved") {
                HyprlandService.refreshMonitors();
                if (root.confirming) {
                    if (Date.now() < root.topologyEventGraceUntil) {
                        root.queueRefresh();
                        return;
                    }
                    confirmationTimer.stop();
                    root.confirming = false;
                    root.confirmationSecondsRemaining = 0;
                    root.topologyRollbackQueued = true;
                    if (!root.loading)
                        root.refresh();
                } else {
                    root.queueRefresh();
                }
            }
        }
    }

    // ── Processes ──────────────────────────────────────────
    Process {
        id: monitorsProc
        command: ["hyprctl", "monitors", "all", "-j"]
        running: false

        stdout: StdioCollector {
            id: monitorsOutput
        }

        stderr: StdioCollector {
            id: monitorsError
        }

        onExited: function(exitCode) {
            root.loading = false;
            try {
                var json = JSON.parse(monitorsOutput.text || "[]");
                if (Array.isArray(json)) {
                    root.monitors = root.sortMonitors(json);
                    if (!root.hasPending) {
                        root.resetDraft();
                    } else {
                        root.ensureSelected();
                    }
                    if (exitCode !== 0)
                        root.errorText = monitorsError.text || "Could not read displays.";
                    else if (!root.rollbackRetryAvailable)
                        root.errorText = "";
                    if (root.topologyRollbackQueued) {
                        root.topologyRollbackQueued = false;
                        Qt.callLater(root.revertDisplayChanges);
                    } else if (root.mirrorQueued) {
                        Qt.callLater(root.runQueuedMirror);
                    } else {
                        Qt.callLater(root.followLid);
                    }
                }
            } catch(e) {
                root.mirrorQueued = false;
                root.errorText = "Could not read displays.";
                console.warn("[Speshell] Failed to parse hyprctl monitors output:", e);
                if (root.topologyRollbackQueued) {
                    root.topologyRollbackQueued = false;
                    Qt.callLater(root.revertDisplayChanges);
                }
            }
        }
    }

    Process {
        id: applyProc
        running: false
        stderr: StdioCollector {
            id: applyError
        }
        onExited: function(exitCode) {
            var completedOperation = root.operationKind;
            root.operationKind = "";
            root.applying = false;
            if (completedOperation === "rollback") {
                root.reverting = false;
                if (exitCode !== 0) {
                    root.rollbackRetryAvailable = true;
                    root.errorText = applyError.text || "Display rollback failed.";
                } else {
                    root.rollbackMonitors = [];
                    root.rollbackRetryAvailable = false;
                    root.errorText = "";
                }
            } else if (exitCode !== 0) {
                root.rollbackMonitors = [];
                root.errorText = applyError.text || "Display change failed.";
            } else {
                root.hasPending = false;
                root.pendingSummary = "";
                root.confirming = true;
                root.confirmationSecondsRemaining = 15;
                root.topologyEventGraceUntil = Date.now() + 1500;
                confirmationTimer.restart();
            }
            root.refresh();
        }
    }
}
