pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    property var player: null
    property real displayedPosition: 0
    property bool viewPresented: false
    readonly property bool hasPlayer: root.player !== null
    readonly property bool playing: root.player !== null
        && root.player.playbackState === MprisPlaybackState.Playing

    function players() {
        return Mpris.players && Mpris.players.values ? Mpris.players.values : [];
    }

    function refreshPlayer() {
        var values = root.players();
        var selected = null;
        for (var i = 0; i < values.length; i++) {
            if (values[i] && values[i].playbackState === MprisPlaybackState.Playing) {
                selected = values[i];
                break;
            }
        }
        if (!selected && root.player && values.indexOf(root.player) >= 0)
            selected = root.player;
        if (!selected) {
            for (var j = 0; j < values.length; j++) {
                if (values[j]) {
                    selected = values[j];
                    break;
                }
            }
        }
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

    function setViewPresented(presented) {
        var next = !!presented;
        if (root.viewPresented === next)
            return;
        root.viewPresented = next;
        if (next)
            root.refreshPlayer();
    }

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
