pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The MPRIS player to show: the one playing, else the last shown, else any.
Singleton {
    id: root

    property var player: null
    property real displayedPosition: 0
    property bool viewPresented: false
    readonly property bool hasPlayer: root.player !== null
    readonly property bool playing: root.player !== null
        && root.player.playbackState === MprisPlaybackState.Playing

    // Untyped: Quickshell's type info leaves the model's values out.
    readonly property var playerModel: Mpris.players

    function players() {
        return root.playerModel && root.playerModel.values ? root.playerModel.values : [];
    }

    function refreshPlayer() {
        const values = root.players().filter(player => !!player);
        const selected = values.find(player => player.playbackState === MprisPlaybackState.Playing)
            ?? (values.indexOf(root.player) >= 0 ? root.player : values[0] ?? null);
        if (root.player !== selected)
            root.player = selected;
        root.displayedPosition = root.player ? Number(root.player.position) || 0 : 0;
    }

    function seek(position) {
        if (!root.player || root.player.length <= 0)
            return;
        root.displayedPosition = Math.max(0, Math.min(root.player.length, Number(position) || 0));
        root.player.position = root.displayedPosition;
    }

    function togglePlaying() {
        if (root.player)
            root.player.togglePlaying();
    }

    function previous() {
        if (root.player)
            root.player.previous();
    }

    function next() {
        if (root.player)
            root.player.next();
    }

    function setViewPresented(presented) {
        const next = !!presented;
        if (root.viewPresented === next)
            return;
        root.viewPresented = next;
    }

    // Starting reads the position at once.
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.viewPresented
        onTriggered: root.refreshPlayer()
    }

    Connections {
        target: Mpris.players // qmllint disable incompatible-type
        function onValuesChanged() { root.refreshPlayer(); }
    }

    // A player starting or pausing can change which one to show.
    Instantiator {
        model: Mpris.players
        delegate: Connections {
            id: playerWatch
            required property var modelData
            target: playerWatch.modelData
            function onPlaybackStateChanged() { root.refreshPlayer(); }
        }
    }

    Component.onCompleted: root.refreshPlayer()
}
