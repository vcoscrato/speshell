import QtQuick
import qs.components
import qs.services
import qs.theme

// The playing track: play/pause in place, and its cover, which opens the player and
// names the track on hover. Hidden while nothing plays media.
Row {
    id: root

    property int itemSize: Theme.controlHeight
    // On a bottom bar: labels show above.
    property bool labelAbove: false
    // Whether the player's dropdown hangs from the cover.
    property bool coverOpen: false
    readonly property var player: MediaService.player
    readonly property alias coverButton: coverButton

    // `pointer`: the MouseArea clicked, or null from the keyboard.
    signal coverClicked(Item pointer)

    visible: root.player !== null
    spacing: Theme.spacingMicro

    BarButton {
        id: playButton
        size: root.itemSize
        labelAbove: root.labelAbove
        label: MediaService.playing ? "Pause" : "Play"
        onClicked: if (root.player) root.player.togglePlaying()

        AppIcon {
            anchors.centerIn: parent
            // The play triangle's weight sits left of its box.
            anchors.horizontalCenterOffset: MediaService.playing ? 0 : 1
            name: MediaService.playing ? "media-pause" : "media-play"
            size: Theme.iconSizeMedium
            iconColor: playButton.pointerInside ? Theme.text : Theme.subtextBright
        }
    }

    BarButton {
        id: coverButton

        readonly property int coverSize: root.itemSize - Theme.spacingSmall

        size: root.itemSize
        labelAbove: root.labelAbove
        open: root.coverOpen
        label: root.player
            ? [root.player.trackTitle || "Unknown track", root.player.trackArtist].filter(Boolean).join(" · ")
            : ""
        onClicked: pointer => root.coverClicked(pointer)

        Rectangle {
            anchors.centerIn: parent
            width: coverButton.coverSize
            height: coverButton.coverSize
            radius: Theme.borderRadius
            color: cover.status === Image.Ready ? "transparent" : Theme.controlFill
            // Dimmed while paused.
            opacity: MediaService.playing || coverButton.pointerInside || coverButton.open ? 1 : Theme.disabledOpacity
            clip: true

            Image {
                id: cover
                anchors.fill: parent
                source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                sourceSize.width: coverButton.coverSize * 2
                sourceSize.height: coverButton.coverSize * 2
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: cover.status === Image.Ready
            }

            AppIcon {
                anchors.centerIn: parent
                visible: cover.status !== Image.Ready
                name: "media"
                size: Theme.iconSizeSmall
                iconColor: coverButton.open ? Theme.accent : Theme.subtextBright
            }
        }
    }
}
