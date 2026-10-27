pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Airplane mode: every radio (Wi-Fi, Bluetooth, mobile broadband) blocked through
// rfkill, as the laptop's airplane key does. `rfkill event` lists each radio as it
// starts and reports every change after.
Singleton {
    id: root

    readonly property bool available: FeatureSupport.supportsAirplaneMode && Object.keys(root.radios).length > 0
    // Whether each radio, by rfkill index, is blocked by software or by a switch.
    property var radios: ({})
    readonly property bool airplaneMode: {
        const states = Object.keys(root.radios).map(index => root.radios[index]);
        return states.length > 0 && states.every(blocked => blocked);
    }
    // Airplane mode set from a panel, which shows it already, keeps the OSD quiet.
    property double osdSuppressedUntil: 0

    // `showOsd`: from a keybinding.
    function setAirplaneMode(on, showOsd) {
        if (!root.available)
            return;
        if (!showOsd)
            root.osdSuppressedUntil = Date.now() + 1500;
        Quickshell.execDetached(["rfkill", on ? "block" : "unblock", "all"]);
    }

    // "…: idx 1 type 2 op 0 soft 0 hard 0": op 0 adds a radio, 1 removes it, 2 changes it.
    function readEvent(line) {
        const match = String(line).match(/idx (\d+) type \d+ op (\d) soft (\d) hard (\d)/);
        if (!match)
            return;
        const was = root.airplaneMode;
        const radios = Object.assign({}, root.radios);
        if (match[2] === "1")
            delete radios[match[1]];
        else
            radios[match[1]] = match[3] === "1" || match[4] === "1";
        root.radios = radios;
        if (match[2] === "2" && root.airplaneMode !== was && Date.now() >= root.osdSuppressedUntil)
            OsdService.show("airplane", root.airplaneMode ? "Airplane mode on" : "Airplane mode off", "", -1);
    }

    Process {
        running: FeatureSupport.supportsAirplaneMode
        // A pipe would hold the events in rfkill's buffer.
        command: ["stdbuf", "-oL", "rfkill", "event"]
        stdout: SplitParser {
            onRead: line => root.readEvent(line)
        }
    }
}
