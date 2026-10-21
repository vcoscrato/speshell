pragma ComponentBehavior: Bound
import QtQuick
import qs.components
import qs.services
import qs.theme
import "../components/Format.js" as Format

// The playing track: its cover, title and artist, position, and the player's controls.
Card {
    id: root
    title: "Now playing"
    iconName: "media"
    property bool presented: false

    readonly property var player: MediaService.player
    readonly property bool hasPlayer: MediaService.hasPlayer

    onPresentedChanged: MediaService.setViewPresented(root.presented)
    Component.onCompleted: MediaService.setViewPresented(root.presented)
    Component.onDestruction: MediaService.setViewPresented(false)

    // ── No player fallback — compact one-liner ──
    Row {
        width: parent.width
        spacing: Theme.spacingSmall
        visible: !root.hasPlayer

        AppIcon {
            name: "media"
            size: Theme.iconSizeMedium
            iconColor: Theme.overlay
            opacity: Theme.disabledOpacity
            anchors.verticalCenter: parent.verticalCenter
        }
        Label {
            text: "No media playing"
            color: Theme.overlay
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ── Player content ───────────────────────
    Column {
        width: parent.width
        spacing: Theme.spacingSmall
        visible: root.hasPlayer

        Row {
            width: parent.width
            spacing: Theme.spacingMedium

            // ── Album art ────────────────────────
            // Square covers fill an 80 px square; wide art such as video thumbnails
            // keeps its shape (up to 16:9) instead of being cropped.
            Rectangle {
                id: artBox
                readonly property real aspect: artImage.status === Image.Ready && artImage.implicitHeight > 0
                    ? artImage.implicitWidth / artImage.implicitHeight
                    : 1
                readonly property bool wide: aspect > 1.2

                width: wide ? 128 : 80
                height: wide ? Math.round(128 / Math.min(aspect, 16 / 9)) : 80
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
                    visible: source !== ""
                }

                // Fallback icon
                AppIcon {
                    anchors.centerIn: parent
                    name: "media"
                    size: 32
                    iconColor: Theme.overlay
                    visible: artImage.status !== Image.Ready
                }
            }

            // ── Track info + controls ────────────
            // Fixed height (two title lines), so Home doesn't shift between tracks.
            Item {
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
                            ? [root.player.trackArtist, root.player.trackAlbum].filter(function(part) {
                                return !!part;
                            }).join(" · ")
                            : ""
                        color: Theme.subtext
                        width: parent.width
                        elide: Text.ElideRight
                    }
                }

                // ── Playback controls ────────────
                Row {
                    id: controlsRow
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingMedium

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "media-previous"
                        tooltipText: "Previous track"
                        onClicked: { if (root.player) root.player.previous() }
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: MediaService.playing ? "media-pause" : "media-play"
                        iconSize: Theme.iconSizeLarge
                        size: 40
                        iconColor: Theme.accent
                        iconXOffset: MediaService.playing ? 0 : 2
                        tooltipText: MediaService.playing
                            ? "Pause"
                            : "Play"
                        onClicked: {
                            if (root.player) root.player.togglePlaying()
                        }
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "media-next"
                        tooltipText: "Next track"
                        onClicked: { if (root.player) root.player.next() }
                    }
                }
            }
        }

        // ── Progress bar ─────────────────────────
        Column {
            width: parent.width
            spacing: Theme.spacingMicro
            visible: root.player && root.player.length > 0

            Rectangle {
                width: parent.width
                height: 4
                radius: 2
                color: Theme.surface2

                Accessible.role: Accessible.Slider
                Accessible.name: "Track position"
                Accessible.description: root.player
                    ? Format.clock(MediaService.displayedPosition)
                        + " of " + Format.clock(root.player.length)
                    : ""

                Rectangle {
                    width: (root.player && root.player.length > 0)
                        ? (MediaService.displayedPosition / root.player.length) * parent.width
                        : 0
                    height: parent.height
                    radius: 2
                    color: Theme.accent
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        if (root.player && root.player.length > 0) {
                            const ratio = mouse.x / parent.width;
                            MediaService.seek(ratio * root.player.length);
                        }
                    }
                }
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
