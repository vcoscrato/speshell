import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// AudioService's default speaker or microphone: its volume and mute, the devices to
// switch between, and what the OSD shows of it.
Scope {
    id: endpoint

    required property bool isOutput
    required property var quickSwitch
    required property var deviceNames
    // What the OSD watches, null while there is nothing to watch.
    property var osdValue: null

    // Its OSD level.
    readonly property string kind: endpoint.isOutput ? "output" : "input"
    readonly property var node: endpoint.isOutput ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource
    readonly property var audio: endpoint.node && endpoint.node.ready ? endpoint.node.audio : null
    readonly property bool hasVolume: endpoint.audio !== null
    readonly property int volumePercent: endpoint.audio ? endpoint.clampPercent(endpoint.audio.volume * 100) : 0
    readonly property bool muted: endpoint.audio ? endpoint.audio.muted : false
    readonly property string deviceLabel: endpoint.node ? endpoint.labelOf(endpoint.node) : ""

    function setVolumePercent(percent) {
        if (!endpoint.audio)
            return;
        OsdService.quiet(endpoint.kind);
        const next = endpoint.clampPercent(percent);
        if (next > 0 && endpoint.audio.muted)
            endpoint.audio.muted = false;
        endpoint.audio.volume = next / 100;
    }

    // Moves the volume by one configured scroll step; direction is positive or negative.
    function stepVolume(direction) {
        if (direction)
            endpoint.setVolumePercent(endpoint.volumePercent + (direction > 0 ? AudioService.scrollStep : -AudioService.scrollStep));
    }

    function toggleMute() {
        if (!endpoint.audio)
            return;
        OsdService.quiet(endpoint.kind);
        endpoint.audio.muted = !endpoint.audio.muted;
    }

    // Its name from [Audio.DeviceNames] or [Audio.InputDeviceNames], or PipeWire's.
    function labelOf(node) {
        for (const candidate of endpoint.nameCandidates(node)) {
            const mapped = String(endpoint.deviceNames[candidate] || "").trim();
            if (mapped !== "")
                return mapped;
        }
        return endpoint.rawDeviceLabel(node);
    }

    // The node's place in the quick-switch list: -1 when the list is empty, -2 when unlisted.
    function quickSwitchIndex(node) {
        if (endpoint.quickSwitch.length === 0)
            return -1;
        const candidates = endpoint.nameCandidates(node).map(candidate => candidate.toLowerCase());
        for (let index = 0; index < endpoint.quickSwitch.length; index++) {
            const needle = String(endpoint.quickSwitch[index] || "").trim().toLowerCase();
            if (needle !== "" && candidates.some(candidate => candidate.indexOf(needle) >= 0))
                return index;
        }
        return -2;
    }

    // The offered devices as {node, label, rawLabel}, in quick-switch order, and the
    // one in use.
    function devices() {
        const result = [];
        for (const node of Pipewire.nodes.values) {
            if (!node || node.isStream || (endpoint.isOutput ? !node.isSink : !endpoint.isSourceNode(node)))
                continue;
            let index = endpoint.quickSwitchIndex(node);
            // The device in use shows even when the quick switch leaves it out, last.
            if (index === -2 && node === endpoint.node)
                index = Number.MAX_SAFE_INTEGER;
            if (index === -2)
                continue;
            result.push({ node: node, label: endpoint.labelOf(node), rawLabel: endpoint.rawDeviceLabel(node), matchIndex: index });
        }
        return result.sort((a, b) => a.matchIndex !== b.matchIndex
            ? a.matchIndex - b.matchIndex
            : a.rawLabel.localeCompare(b.rawLabel));
    }

    function setDevice(node) {
        if (!node)
            return;
        if (endpoint.isOutput)
            Pipewire.preferredDefaultAudioSink = node;
        else
            Pipewire.preferredDefaultAudioSource = node;
    }

    // The next offered device, after the one in use.
    function cycleDevice() {
        const list = endpoint.devices();
        const index = list.findIndex(entry => entry.node === endpoint.node);
        const next = list.length > 0 ? list[(index + 1) % list.length].node : null;
        if (next && next !== endpoint.node)
            endpoint.setDevice(next);
    }

    // Switching devices or binding a new one changes the values without a volume
    // change.
    onNodeChanged: OsdService.quiet(endpoint.kind)
    onHasVolumeChanged: OsdService.quiet(endpoint.kind)
    onOsdValueChanged: osdDebounce.restart()

    // A step that unmutes changes both at once; they show as one.
    Timer {
        id: osdDebounce
        interval: 30
        onTriggered: {
            if (OsdService.changed(endpoint.kind, endpoint.osdValue))
                OsdService.showLevel(endpoint.kind);
        }
    }

    function clampPercent(value) {
        return Math.max(0, Math.min(100, Math.round(Number(value) || 0)));
    }

    function nameCandidates(node) {
        const candidates = [];
        for (const value of [node.name, node.description]) {
            const text = String(value || "").trim();
            if (text !== "" && candidates.indexOf(text) < 0)
                candidates.push(text);
        }
        return candidates;
    }

    function rawDeviceLabel(node) {
        return node.description || node.name || "Unknown";
    }

    function isSourceNode(node) {
        if (node.isSource)
            return true;
        const mediaClass = typeof node.mediaClass === "string" ? node.mediaClass : "";
        if (mediaClass.indexOf("Audio/Source") === 0)
            return true;
        const name = typeof node.name === "string" ? node.name : "";
        if (name.indexOf(".monitor") !== -1)
            return false;
        return name.indexOf("alsa_input.") === 0 || name.indexOf(".input.") !== -1;
    }
}
