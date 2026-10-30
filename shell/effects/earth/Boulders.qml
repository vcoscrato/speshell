import QtQuick

// Rocks held aloft around the open launcher: boulders that rise out of the ground one
// after another, bob and tumble slowly while the launcher is open, and drop back when
// it closes, with pebbles circling the bigger ones, a ring of small stones far out
// behind them, bands of dust, and motes rising past in front.
//
// Only the dust bands fill the item. Each stone, boulder, and mote is a quad of its
// own that Boulders.vert fits to where it is, so a pixel pays only for the pieces over
// it; one shader that drew them all was far too slow for an integrated GPU.
Item {
    id: root

    property real time: 0
    property rect panel
    property real ground: 0
    property real lift: 0
    property real fall: 0
    property color cLight
    property color cMid
    property color cDark
    property color cEdge

    // The uniforms Boulders.glsl declares, in the item's coordinates.
    component Piece: ShaderEffect {
        required property Item host
        property real kind: 0
        property real piece: 0
        anchors.fill: parent
        property real time: host.time
        property rect rect: Qt.rect(host.x, host.y, host.width, host.height)
        property rect panel: host.panel
        property real ground: host.ground
        property real lift: host.lift
        property real fall: host.fall
        property color cLight: host.cLight
        property color cMid: host.cMid
        property color cDark: host.cDark
        property color cEdge: host.cEdge
        vertexShader: kind < 0 ? "" : Qt.resolvedUrl("qsb/Boulders.vert.qsb")
    }

    // Drawn back to front: the dust bands, the far stones, the boulders, the motes.
    Piece {
        host: root
        kind: -1
        fragmentShader: Qt.resolvedUrl("qsb/Boulders.qsb")
    }

    Repeater {
        model: 14
        Piece {
            required property int index
            host: root
            kind: 0
            piece: index
            fragmentShader: Qt.resolvedUrl("qsb/Boulders.stone.qsb")
        }
    }

    Repeater {
        model: 7
        Piece {
            required property int index
            host: root
            kind: 1
            piece: index
            fragmentShader: Qt.resolvedUrl("qsb/Boulders.rock.qsb")
        }
    }

    Repeater {
        model: 26
        Piece {
            required property int index
            host: root
            kind: 2
            piece: index
            fragmentShader: Qt.resolvedUrl("qsb/Boulders.mote.qsb")
        }
    }
}
