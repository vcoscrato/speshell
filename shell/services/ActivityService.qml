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
        const state = String(value || "").trim().toLowerCase();
        if (root.activeStates.indexOf(state) >= 0)
            return state;
        if (root.inactiveStates.indexOf(state) >= 0)
            return "inactive";
        return "";
    }

    function normalizedTone(value) {
        const tone = String(value || "neutral").trim().toLowerCase();
        return root.tones.indexOf(tone) >= 0 ? tone : "neutral";
    }

    function normalizedId(value) {
        const id = String(value || "").trim().toLowerCase();
        return /^[a-z0-9][a-z0-9._-]*$/.test(id) ? id : "";
    }

    function normalizedProvider(value) {
        return root.normalizedId(value) || "unknown";
    }

    function finiteNumber(value, fallback) {
        const number = Number(value);
        return isFinite(number) ? number : fallback;
    }

    function normalizedActions(value) {
        if (!Array.isArray(value))
            return [];
        const result = [];
        const seen = Object.create(null);
        for (let i = 0; i < value.length; i++) {
            const supplied = value[i] || ({});
            const id = root.normalizedId(supplied.id);
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
        const supplied = suppliedValue || ({});
        const state = root.normalizedState(supplied.state);
        const id = root.normalizedId(supplied.id);
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
        const winners = Object.create(null);
        Object.keys(root.providerActivities).forEach(provider => {
            const entries = root.providerActivities[provider];
            Object.keys(entries).forEach(id => {
                const candidate = entries[id];
                const current = winners[id];
                if (!current
                        || candidate.priority > current.priority
                        || (candidate.priority === current.priority
                            && candidate.updatedAt >= current.updatedAt))
                    winners[id] = candidate;
            });
        });

        const result = Object.keys(winners).map(id => winners[id]);
        result.sort((left, right) => {
            if (left.sortOrder !== right.sortOrder)
                return left.sortOrder - right.sortOrder;
            if (left.startedAt !== right.startedAt)
                return left.startedAt - right.startedAt;
            return left.id.localeCompare(right.id);
        });
        root.activities = result;
    }

    function publish(providerValue, suppliedValue) {
        const provider = root.normalizedProvider(providerValue);
        const supplied = suppliedValue || ({});
        const id = root.normalizedId(supplied.id);
        const state = root.normalizedState(supplied.state);
        if (id === "" || state === "")
            return false;

        const providers = Object.assign({}, root.providerActivities);
        const entries = Object.assign({}, providers[provider] || ({}));
        const entry = root.normalizeEntry(provider, supplied, entries[id], Date.now());
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
        const provider = root.normalizedProvider(providerValue);
        const providers = Object.assign({}, root.providerActivities);
        const previous = providers[provider] || ({});
        const next = ({});
        const source = Array.isArray(suppliedEntries) ? suppliedEntries : [];
        const now = Date.now();

        for (let i = 0; i < source.length; i++) {
            const supplied = source[i] || ({});
            const id = root.normalizedId(supplied.id);
            const entry = root.normalizeEntry(provider, supplied, previous[id], now);
            if (entry)
                next[id] = entry;
        }

        providers[provider] = next;
        root.providerActivities = providers;
        root.rebuild();
    }

    function clear(providerValue, activityIdValue) {
        const provider = root.normalizedProvider(providerValue);
        const activityId = root.normalizedId(activityIdValue);
        const providers = Object.assign({}, root.providerActivities);
        const entries = Object.assign({}, providers[provider] || ({}));
        if (!Object.prototype.hasOwnProperty.call(entries, activityId))
            return false;

        delete entries[activityId];
        providers[provider] = entries;
        root.providerActivities = providers;
        root.rebuild();
        return true;
    }

    function clearProvider(providerValue) {
        const provider = root.normalizedProvider(providerValue);
        if (!Object.prototype.hasOwnProperty.call(root.providerActivities, provider))
            return;
        const providers = Object.assign({}, root.providerActivities);
        delete providers[provider];
        root.providerActivities = providers;
        root.rebuild();
    }

    function requestAction(providerValue, activityIdValue, actionIdValue) {
        const provider = root.normalizedProvider(providerValue);
        const activityId = root.normalizedId(activityIdValue);
        const actionId = root.normalizedId(actionIdValue);
        const entries = root.providerActivities[provider] || ({});
        const entry = entries[activityId];
        if (!entry)
            return false;

        for (let i = 0; i < entry.actions.length; i++) {
            if (entry.actions[i].id === actionId) {
                root.actionRequested(provider, activityId, actionId);
                return true;
            }
        }
        return false;
    }
}
