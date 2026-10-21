pragma Singleton

import QtQuick
import Quickshell

// The on-screen display at the bottom of the focused screen, for a level or a state
// changed from outside Speshell's panels: volume and brightness keys, the microphone's
// mute, the touchpad, airplane mode.
Singleton {
    id: root

    // `level` from 0 to 1 draws a bar under the title; -1 draws none.
    signal requested(string iconName, string title, string value, real level)

    function show(iconName, title, value, level) {
        root.requested(String(iconName || "info"), String(title || ""), String(value || ""),
            level === undefined ? -1 : Number(level));
    }

    // A percent, as its text and its bar.
    function showPercent(iconName, title, percent) {
        const value = Math.max(0, Math.min(100, Math.round(Number(percent) || 0)));
        root.show(iconName, title, value + "%", value / 100);
    }
}
