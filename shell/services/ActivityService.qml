pragma Singleton

import QtQuick
import Quickshell

// What's running, for the bar's chips: activities published by providers (Speshell's
// tools, `speshell activity`), one per id, and the actions they offer.
Singleton {
    id: root

    property var providerActivities: ({})
    property var activities: []

    readonly property var activeStates: ["active", "busy", "paused", "error"]
    readonly property var inactiveStates: ["idle", "inactive", "stopped", "complete"]
    readonly property var tones: ["neutral", "accent", "success", "warning", "error"]

    signal actionRequested(string provider, string activityId, string actionId)

    function normalizedState(value) {
        var state = String(value || "").trim().toLowerCase();
        if (root.activeStates.indexOf(state) >= 0)
            return state;
        if (root.inactiveStates.indexOf(state) >= 0)
            return "inactive";
        return "";
    }

    function normalizedTone(value) {
        var tone = String(value || "neutral").trim().toLowerCase();
        return root.tones.indexOf(tone) >= 0 ? tone : "neutral";
    }

    function normalizedId(value) {
        var id = String(value || "").trim().toLowerCase();
        return /^[a-z0-9][a-z0-9._-]*$/.test(id) ? id : "";
    }

    function normalizedProvider(value) {
        return root.normalizedId(value) || "unknown";
    }

    function finiteNumber(value, fallback) {
        var number = Number(value);
        return isFinite(number) ? number : fallback;
    }

    function normalizedActions(value) {
        if (!Array.isArray(value))
            return [];
        var result = [];
        var seen = Object.create(null);
        for (var i = 0; i < value.length; i++) {
            var supplied = value[i] || ({});
            var id = root.normalizedId(supplied.id);
            if (id === "" || seen[id])
                continue;
            seen[id] = true;
            result.push({ id: id, label: String(supplied.label || id).trim() });
        }
        return result;
    }

    // A published activity as the bar reads it, or null when it is invalid or over.
    // An activity that was already running keeps its start time.
    function normalizeEntry(provider, suppliedValue, previous, now) {
        var supplied = suppliedValue || ({});
        var state = root.normalizedState(supplied.state);
        var id = root.normalizedId(supplied.id);
        if (id === "" || state === "" || state === "inactive")
            return null;

        return {
            key: provider + ":" + id,
            provider: provider,
            id: id,
            state: state,
            label: String(supplied.label || id).trim(),
            detail: String(supplied.detail || "").trim(),
            iconName: String(supplied.iconName || "info").trim(),
            tone: root.normalizedTone(supplied.tone),
            actions: root.normalizedActions(supplied.actions),
            startedAt: previous ? previous.startedAt : root.finiteNumber(supplied.startedAt, now),
            updatedAt: now,
            priority: root.finiteNumber(supplied.priority, 0),
            sortOrder: root.finiteNumber(supplied.sortOrder, 100)
        };
    }

    // One entry per activity id across providers: the highest priority wins, then the
    // latest update. Sorted by sortOrder, then start time.
    function rebuild() {
        var winners = Object.create(null);
        Object.keys(root.providerActivities).forEach(function(provider) {
            var entries = root.providerActivities[provider];
            Object.keys(entries).forEach(function(id) {
                var candidate = entries[id];
                var current = winners[id];
                if (!current
                        || candidate.priority > current.priority
                        || (candidate.priority === current.priority
                            && candidate.updatedAt >= current.updatedAt))
                    winners[id] = candidate;
            });
        });

        var result = Object.keys(winners).map(function(id) { return winners[id]; });
        result.sort(function(left, right) {
            if (left.sortOrder !== right.sortOrder)
                return left.sortOrder - right.sortOrder;
            if (left.startedAt !== right.startedAt)
                return left.startedAt - right.startedAt;
            return left.id.localeCompare(right.id);
        });
        root.activities = result;
    }

    function publish(providerValue, suppliedValue) {
        var provider = root.normalizedProvider(providerValue);
        var supplied = suppliedValue || ({});
        var id = root.normalizedId(supplied.id);
        var state = root.normalizedState(supplied.state);
        if (id === "" || state === "")
            return false;

        var providers = Object.assign({}, root.providerActivities);
        var entries = Object.assign({}, providers[provider] || ({}));
        var entry = root.normalizeEntry(provider, supplied, entries[id], Date.now());
        if (entry)
            entries[id] = entry;
        else
            delete entries[id];

        providers[provider] = entries;
        root.providerActivities = providers;
        root.rebuild();
        return entry !== null;
    }

    function replaceProvider(providerValue, suppliedEntries) {
        var provider = root.normalizedProvider(providerValue);
        var providers = Object.assign({}, root.providerActivities);
        var previous = providers[provider] || ({});
        var next = ({});
        var source = Array.isArray(suppliedEntries) ? suppliedEntries : [];
        var now = Date.now();

        for (var i = 0; i < source.length; i++) {
            var supplied = source[i] || ({});
            var id = root.normalizedId(supplied.id);
            var entry = root.normalizeEntry(provider, supplied, previous[id], now);
            if (entry)
                next[id] = entry;
        }

        providers[provider] = next;
        root.providerActivities = providers;
        root.rebuild();
    }

    function clear(providerValue, activityIdValue) {
        var provider = root.normalizedProvider(providerValue);
        var activityId = root.normalizedId(activityIdValue);
        var providers = Object.assign({}, root.providerActivities);
        var entries = Object.assign({}, providers[provider] || ({}));
        if (!Object.prototype.hasOwnProperty.call(entries, activityId))
            return false;

        delete entries[activityId];
        providers[provider] = entries;
        root.providerActivities = providers;
        root.rebuild();
        return true;
    }

    function clearProvider(providerValue) {
        var provider = root.normalizedProvider(providerValue);
        if (!Object.prototype.hasOwnProperty.call(root.providerActivities, provider))
            return;
        var providers = Object.assign({}, root.providerActivities);
        delete providers[provider];
        root.providerActivities = providers;
        root.rebuild();
    }

    function requestAction(providerValue, activityIdValue, actionIdValue) {
        var provider = root.normalizedProvider(providerValue);
        var activityId = root.normalizedId(activityIdValue);
        var actionId = root.normalizedId(actionIdValue);
        var entries = root.providerActivities[provider] || ({});
        var entry = entries[activityId];
        if (!entry)
            return false;

        for (var i = 0; i < entry.actions.length; i++) {
            if (entry.actions[i].id === actionId) {
                root.actionRequested(provider, activityId, actionId);
                return true;
            }
        }
        return false;
    }
}
