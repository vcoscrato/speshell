pragma Singleton

import QtQuick
import Quickshell

// What's running, for the bar's chips: the tools' activities, which ToolsService finds,
// and those published with `speshell activity`, which stand in for a tool's of the same
// id (as dictation's model download does for dictation).
Singleton {
    id: root

    // Each activity is { id, state, label, detail, iconName, tone, actions, startedAt }:
    // `state` is "active" or "busy", and `actions` what a click on its chip does, as
    // [{ id, label }].
    property var toolActivities: []
    // Published with `speshell activity`.
    property var published: []
    // All of them, oldest first.
    readonly property var activities: root.toolActivities
        .filter(activity => !root.published.some(other => other.id === activity.id))
        .concat(root.published)
        .sort((a, b) => a.startedAt - b.startedAt)

    readonly property var states: ["active", "busy"]
    readonly property var tones: ["neutral", "accent", "success", "warning", "error"]

    signal actionRequested(string activityId, string actionId)

    // `supplied` as an activity; one that was already running keeps its start time.
    function entry(supplied, previous) {
        return {
            id: supplied.id,
            state: supplied.state,
            label: String(supplied.label || supplied.id).trim(),
            detail: String(supplied.detail || "").trim(),
            iconName: String(supplied.iconName || "info").trim(),
            tone: supplied.tone || "neutral",
            actions: supplied.actions || [],
            startedAt: previous ? previous.startedAt : (supplied.startedAt || Date.now())
        };
    }

    // ToolsService's activities, replacing the last unless they're the same.
    function setTools(supplied) {
        const key = list => list.map(activity => activity.id + ":" + activity.state).join(",");
        if (key(supplied) === key(root.toolActivities))
            return;
        const previous = {};
        root.toolActivities.forEach(activity => previous[activity.id] = activity);
        root.toolActivities = supplied.map(activity => root.entry(activity, previous[activity.id]));
    }

    // From `speshell activity set`: false when the id, state, or tone isn't one.
    function publish(id, state, label, detail, iconName, tone) {
        const supplied = {
            id: String(id || "").trim().toLowerCase(),
            state: String(state || "").trim().toLowerCase(),
            label: label,
            detail: detail,
            iconName: iconName,
            tone: String(tone || "neutral").trim().toLowerCase()
        };
        if (!/^[a-z0-9][a-z0-9._-]*$/.test(supplied.id) || root.states.indexOf(supplied.state) < 0
                || root.tones.indexOf(supplied.tone) < 0)
            return false;
        const previous = root.published.find(activity => activity.id === supplied.id);
        root.published = root.published.filter(activity => activity !== previous)
            .concat([root.entry(supplied, previous)]);
        return true;
    }

    function clear(id) {
        const key = String(id || "").trim().toLowerCase();
        const published = root.published.filter(activity => activity.id !== key);
        if (published.length === root.published.length)
            return false;
        root.published = published;
        return true;
    }

    // A click on a chip: its activity's action `actionId`.
    function requestAction(activityId, actionId) {
        const activity = root.activities.find(activity => activity.id === activityId);
        if (activity && activity.actions.some(action => action.id === actionId))
            root.actionRequested(activityId, actionId);
    }
}
