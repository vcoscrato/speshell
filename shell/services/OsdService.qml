pragma Singleton

import QtQuick
import Quickshell

// The on-screen display at the bottom of the focused screen, for a level or a state
// changed from outside Speshell's panels: volume and brightness keys, the microphone's
// mute, the touchpad, airplane mode.
Singleton {
    id: root

    // What each watched value last read, by key, so only a real change shows.
    property var seen: ({})
    // Until when each key keeps quiet, after a change Speshell made itself.
    property var quietUntil: ({})

    // `level` names a level the OSD shows live, as its panel does, for the pointer to
    // set: "output", "input", "brightness", or "keyboard". Without one, it shows a state.
    signal requested(string level, string iconName, string title, string detail)

    function showLevel(level) {
        root.requested(String(level), "", "", "");
    }

    function show(iconName, title, detail) {
        root.requested("", String(iconName || "info"), String(title || ""), String(detail || ""));
    }

    // Keeps `key` quiet for a moment: a change Speshell made, which shows where it was
    // made, or a device switch, which changes the values by itself.
    function quiet(key) {
        root.quietUntil[key] = Math.max(root.quietUntil[key] || 0, Date.now() + 1200);
    }

    // Whether `value`, as `key` reads now, is a change to show: not its first reading,
    // nor one while it keeps quiet. Null forgets it, as when its device goes.
    function changed(key, value) {
        const known = Object.prototype.hasOwnProperty.call(root.seen, key);
        const differs = known && root.seen[key] !== value;
        if (value === null || value === undefined)
            delete root.seen[key];
        else
            root.seen[key] = value;
        return differs && value !== null && value !== undefined && Date.now() >= (root.quietUntil[key] || 0);
    }
}
