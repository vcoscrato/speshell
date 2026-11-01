import QtQuick
import qs.components
import qs.services

// The volume of an AudioService endpoint, the speaker or the microphone, after its mute
// button, as its panel and the OSD show it.
LevelRow {
    id: root

    required property var endpoint

    value: root.endpoint.volumePercent
    valueText: !root.endpoint.node ? "—" : root.endpoint.muted ? "Muted"
        : (root.endpoint.hasVolume ? root.endpoint.volumePercent + "%" : "…")
    adjustable: root.endpoint.hasVolume
    // Muted, the level stays settable but reads as silent.
    progressColor: root.endpoint.muted ? Theme.overlay : Theme.accent
    stepSize: AudioService.scrollStep
    onAdjusted: nextValue => root.endpoint.setVolumePercent(Math.round(nextValue))

    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        iconName: "audio-" + root.endpoint.kind + (root.endpoint.muted ? "-muted" : "")
        iconColor: root.endpoint.muted ? Theme.subtext : Theme.text
        tooltipText: (root.endpoint.muted ? "Unmute " : "Mute ") + root.endpoint.kind
        onClicked: root.endpoint.toggleMute()
    }
}
