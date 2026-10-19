pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default output and input volume through Quickshell's PipeWire bindings.
Singleton {
    id: root

    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property var defaultSource: Pipewire.defaultAudioSource
    readonly property var sinkAudio: root.defaultSink && root.defaultSink.ready ? root.defaultSink.audio : null
    readonly property var sourceAudio: root.defaultSource && root.defaultSource.ready ? root.defaultSource.audio : null

    readonly property bool hasOutputVolume: root.sinkAudio !== null
    readonly property int outputVolumePercent: root.sinkAudio ? root.clampPercent(root.sinkAudio.volume * 100) : 0
    readonly property bool outputMuted: root.sinkAudio ? root.sinkAudio.muted : false

    readonly property bool hasInputVolume: root.sourceAudio !== null
    readonly property int inputVolumePercent: root.sourceAudio ? root.clampPercent(root.sourceAudio.volume * 100) : 0
    readonly property bool inputMuted: root.sourceAudio ? root.sourceAudio.muted : false

    readonly property int scrollStep: ConfigService.settings.audio.scrollStep
    // [Audio.QuickSwitch] and friends: the devices to offer, in order, as name
    // substrings (all devices when empty), and display names by PipeWire name or description.
    readonly property var outputQuickSwitch: ConfigService.settings.audio.quickSwitch
    readonly property var outputDeviceNames: ConfigService.settings.audio.deviceNames
    readonly property var inputQuickSwitch: ConfigService.settings.audio.inputQuickSwitch
    readonly property var inputDeviceNames: ConfigService.settings.audio.inputDeviceNames

    readonly property string outputDeviceLabel: root.defaultSink ? root.deviceLabel(root.defaultSink, true) : ""
    readonly property string inputDeviceLabel: root.defaultSource ? root.deviceLabel(root.defaultSource, false) : ""
    property double outputOsdSuppressedUntil: 0
    // The output level the OSD last saw, so it only shows for real changes.
    property int osdVolumePercent: -1
    property bool osdMuted: false

    // Emitted for output changes made outside Speshell, such as media keys.
    signal outputOsdRequested(int volumePercent, bool muted)

    function clampPercent(value) {
        return Math.max(0, Math.min(100, Math.round(Number(value) || 0)));
    }

    function suppressOutputOsd(durationMs) {
        root.outputOsdSuppressedUntil = Math.max(root.outputOsdSuppressedUntil, Date.now() + durationMs);
    }

    function queueOutputOsd() {
        if (root.hasOutputVolume)
            outputOsdDebounce.restart();
    }

    function setVolume(audio, percent) {
        if (!audio)
            return;
        var next = root.clampPercent(percent);
        if (next > 0 && audio.muted)
            audio.muted = false;
        audio.volume = next / 100;
    }

    function setOutputVolumePercent(percent) {
        root.suppressOutputOsd(1200);
        root.setVolume(root.sinkAudio, percent);
    }

    function setInputVolumePercent(percent) {
        root.setVolume(root.sourceAudio, percent);
    }

    function toggleOutputMute() {
        if (!root.sinkAudio)
            return;
        root.suppressOutputOsd(1200);
        root.sinkAudio.muted = !root.sinkAudio.muted;
    }

    function toggleInputMute() {
        if (root.sourceAudio)
            root.sourceAudio.muted = !root.sourceAudio.muted;
    }

    // Moves volume by one configured scroll step; direction is positive or negative.
    function stepOutputVolume(direction) {
        if (direction)
            root.setOutputVolumePercent(root.outputVolumePercent + (direction > 0 ? root.scrollStep : -root.scrollStep));
    }

    function stepInputVolume(direction) {
        if (direction)
            root.setInputVolumePercent(root.inputVolumePercent + (direction > 0 ? root.scrollStep : -root.scrollStep));
    }

    function nameCandidates(node) {
        var candidates = [];
        var values = [node.name, node.description];
        for (var i = 0; i < values.length; i++) {
            var value = String(values[i] || "").trim();
            if (value !== "" && candidates.indexOf(value) < 0)
                candidates.push(value);
        }
        return candidates;
    }

    function rawDeviceLabel(node) {
        return node.description || node.name || "Unknown";
    }

    function deviceLabel(node, isOut) {
        var names = isOut ? root.outputDeviceNames : root.inputDeviceNames;
        var candidates = root.nameCandidates(node);
        for (var i = 0; i < candidates.length; i++) {
            var mapped = String(names[candidates[i]] || "").trim();
            if (mapped !== "")
                return mapped;
        }
        return root.rawDeviceLabel(node);
    }

    // The node's place in the quick-switch list: -1 when the list is empty, -2 when unlisted.
    function quickSwitchIndex(node, isOut) {
        var configured = isOut ? root.outputQuickSwitch : root.inputQuickSwitch;
        if (configured.length === 0)
            return -1;
        var candidates = root.nameCandidates(node);
        for (var configuredIndex = 0; configuredIndex < configured.length; configuredIndex++) {
            var needle = String(configured[configuredIndex] || "").trim().toLowerCase();
            if (needle === "")
                continue;
            for (var candidateIndex = 0; candidateIndex < candidates.length; candidateIndex++) {
                if (candidates[candidateIndex].toLowerCase().indexOf(needle) >= 0)
                    return configuredIndex;
            }
        }
        return -2;
    }

    function isSourceNode(node) {
        if (node.isSource)
            return true;
        var mediaClass = typeof node.mediaClass === "string" ? node.mediaClass : "";
        if (mediaClass.indexOf("Audio/Source") === 0)
            return true;
        var name = typeof node.name === "string" ? node.name : "";
        if (name.indexOf(".monitor") !== -1)
            return false;
        return name.indexOf("alsa_input.") === 0 || name.indexOf(".input.") !== -1;
    }

    // The offered output or input devices as {node, label, rawLabel}, in quick-switch order.
    function devices(isOut) {
        var values = Pipewire.nodes && Pipewire.nodes.values ? Pipewire.nodes.values : [];
        var result = [];
        for (var i = 0; i < values.length; i++) {
            var node = values[i];
            if (!node || node.isStream || (isOut ? !node.isSink : !root.isSourceNode(node)))
                continue;
            var index = root.quickSwitchIndex(node, isOut);
            if (index === -2)
                continue;
            result.push({
                node: node,
                label: root.deviceLabel(node, isOut),
                rawLabel: root.rawDeviceLabel(node),
                matchIndex: index
            });
        }
        result.sort(function(a, b) {
            if (a.matchIndex !== b.matchIndex)
                return a.matchIndex - b.matchIndex;
            return a.rawLabel.localeCompare(b.rawLabel);
        });
        return result;
    }

    function cycleDevice(isOut) {
        var list = root.devices(isOut);
        var current = isOut ? root.defaultSink : root.defaultSource;
        var index = -1;
        for (var i = 0; i < list.length; i++) {
            if (list[i].node === current)
                index = i;
        }
        var next = list.length > 0 ? list[(index + 1) % list.length].node : null;
        if (!next || next === current)
            return;
        if (isOut)
            root.setDefaultSink(next);
        else
            root.setDefaultSource(next);
    }

    function cycleOutputDevice() {
        root.cycleDevice(true);
    }

    function cycleInputDevice() {
        root.cycleDevice(false);
    }

    function setDefaultSink(node) {
        if (node)
            Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node) {
        if (node)
            Pipewire.preferredDefaultAudioSource = node;
    }

    // Switching devices or binding a new one changes the values without a
    // user volume change, so keep the OSD quiet for a moment.
    onDefaultSinkChanged: root.suppressOutputOsd(1200)
    onHasOutputVolumeChanged: root.suppressOutputOsd(1200)
    onSinkAudioChanged: outputOsdDebounce.restart()

    PwObjectTracker {
        objects: [root.defaultSink, root.defaultSource].filter(function(node) { return !!node; })
    }

    // PipeWire re-reports the device volume when a stream links to the sink (an app
    // starting playback or joining a call), so the signals fire without a change.
    Connections {
        target: root.sinkAudio

        function onVolumesChanged() { root.queueOutputOsd(); }
        function onMutedChanged() { root.queueOutputOsd(); }
    }

    Timer {
        id: outputOsdDebounce
        interval: 30
        repeat: false
        onTriggered: {
            var changed = root.osdVolumePercent >= 0
                && (root.outputVolumePercent !== root.osdVolumePercent || root.outputMuted !== root.osdMuted);
            root.osdVolumePercent = root.hasOutputVolume ? root.outputVolumePercent : -1;
            root.osdMuted = root.outputMuted;
            if (changed && Date.now() >= root.outputOsdSuppressedUntil)
                root.outputOsdRequested(root.outputVolumePercent, root.outputMuted);
        }
    }
}
