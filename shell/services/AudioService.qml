pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// The default speaker (`output`) and microphone (`input`) through Quickshell's PipeWire
// bindings: their volume and mute, and the devices to switch between.
Singleton {
    id: root

    readonly property int scrollStep: ConfigService.settings.audio.scrollStep

    // [Audio.QuickSwitch] and friends: the devices to offer, in order, as name
    // substrings (all devices when empty), and display names by PipeWire name or description.
    readonly property AudioEndpoint output: AudioEndpoint {
        isOutput: true
        quickSwitch: ConfigService.settings.audio.quickSwitch
        deviceNames: ConfigService.settings.audio.deviceNames
        // The OSD shows the volume and the mute changed outside Speshell, as by media keys.
        osdValue: hasVolume ? volumePercent + (muted ? " muted" : "") : null
    }

    readonly property AudioEndpoint input: AudioEndpoint {
        isOutput: false
        quickSwitch: ConfigService.settings.audio.inputQuickSwitch
        deviceNames: ConfigService.settings.audio.inputDeviceNames
        // Only the mute: apps adjust the microphone's level on their own.
        osdValue: audio ? muted : null
    }

    PwObjectTracker {
        objects: [root.output.node, root.input.node].filter(node => !!node)
    }
}
