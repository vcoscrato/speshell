pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.services
import "../components/Format.js" as Format

// The playing track: its cover, title and artist, position, and the player's controls.
Card {
    id: root
    panel: "media"

    readonly property var player: MediaService.player
    readonly property bool hasPlayer: MediaService.hasPlayer

    Component.onCompleted: MediaService.setViewPresented(true)
    Component.onDestruction: MediaService.setViewPresented(false)

    EmptyState {
        visible: !root.hasPlayer
        iconName: "media"
        title: "Nothing playing"
        detail: "Music and videos you play show up here."
    }

    Column {
        width: parent.width
        spacing: Theme.spacingSmall
        visible: root.hasPlayer

        Row {
            width: parent.width
            spacing: Theme.spacingMedium

            // Square covers are as tall as the track's details; wide art such as video
            // thumbnails keeps its shape (up to 16:9), half as wide again, instead of
            // being cropped.
            Rectangle {
                id: artBox
                readonly property real aspect: artImage.status === Image.Ready && artImage.implicitHeight > 0
                    ? artImage.implicitWidth / artImage.implicitHeight
                    : 1
                readonly property bool wide: aspect > 1.2

                width: wide ? Math.round(info.height * 1.5) : info.height
                height: wide ? Math.round(width / Math.min(aspect, 16 / 9)) : info.height
                anchors.verticalCenter: parent.verticalCenter
                radius: Theme.borderRadius
                color: Theme.surface2
                clip: true

                Image {
                    id: artImage
                    anchors.fill: parent
                    source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: artImage.status === Image.Ready
                }

                AppIcon {
                    anchors.centerIn: parent
                    name: "media"
                    size: Theme.iconSizeLarge
                    iconColor: Theme.overlay
                    visible: artImage.status !== Image.Ready
                }
            }

            // As tall as two title lines, so the panel keeps its height between tracks.
            Item {
                id: info
                width: parent.width - artBox.width - Theme.spacingMedium
                height: titleMetrics.lineSpacing * 2 + artistText.height + Theme.spacingTiny + controlsRow.height

                FontMetrics {
                    id: titleMetrics
                    font.pixelSize: Theme.fontSizeNormal
                    font.weight: Font.Medium
                    font.family: Theme.fontFamily
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingMicro

                    Label {
                        role: "title"
                        text: root.player ? (root.player.trackTitle || "Unknown track") : ""
                        width: parent.width
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Label {
                        id: artistText
                        text: root.player
                            ? [root.player.trackArtist, root.player.trackAlbum].filter(Boolean).join(" · ")
                            : ""
                        color: Theme.subtext
                        width: parent.width
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: controlsRow
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingMedium

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "media-previous"
                        tooltipText: "Previous track"
                        onClicked: MediaService.previous()
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: MediaService.playing ? "media-pause" : "media-play"
                        iconSize: Theme.iconSizeLarge
                        size: Theme.controlHeight + Theme.spacingSmall
                        iconColor: Theme.accent
                        iconXOffset: MediaService.playing ? 0 : 2
                        tooltipText: MediaService.playing
                            ? "Pause"
                            : "Play"
                        onClicked: MediaService.togglePlaying()
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "media-next"
                        tooltipText: "Next track"
                        onClicked: MediaService.next()
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: Theme.spacingMicro
            visible: root.player !== null && root.player.length > 0

            // A drag seeks where it lets go; the wheel by five seconds.
            StyledSlider {
                width: parent.width
                to: Math.max(1, root.player ? root.player.length : 1)
                value: MediaService.displayedPosition
                stepSize: 5
                live: false
                Accessible.name: "Track position"
                onPressedChanged: if (!pressed) MediaService.seek(valueAt(position))
                onStepped: nextValue => MediaService.seek(nextValue)
            }

            Row {
                width: parent.width

                Label {
                    id: elapsedText
                    text: root.player ? Format.clock(MediaService.displayedPosition) : "0:00"
                    font.features: { "tnum": 1 }
                    color: Theme.subtext
                }

                Item {
                    width: Math.max(0, parent.width - elapsedText.width - totalText.width)
                    height: 1
                }

                Label {
                    id: totalText
                    text: root.player ? Format.clock(root.player.length) : "0:00"
                    font.features: { "tnum": 1 }
                    color: Theme.subtext
                }
            }
        }
    }
}
