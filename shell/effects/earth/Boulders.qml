import QtQuick

// Rocks held aloft around the open launcher: boulders that rise out of the ground one
// after another, bob and tumble slowly while the launcher is open, and drop back when
// it closes, with pebbles circling the bigger ones, a ring of small stones far out
// behind them, bands of dust, and motes rising past in front.
//
// Each piece is a box of its own, and each dust band a strip along the arc it covers,
// in the mesh of one of three draws that Boulders.vert fits to where they are, so a
// pixel pays only for the pieces over it, and the GPU gets three draws rather than one
// for every piece.
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

    // The uniforms Boulders.glsl declares, in the item's coordinates. Its rows are
    // four for each piece, and SEGMENTS + 3 for each band (Boulders.glsl).
    component Pieces: ShaderEffect {
        required property Item host
        property real kind: 0
        property real rows: 4
        anchors.fill: parent
        mesh: GridMesh {
            resolution: Qt.size(1, rows - 1)
        }
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
        vertexShader: Qt.resolvedUrl("qsb/Boulders.vert.qsb")
    }

    // Drawn back to front: the two dust bands and the 14 far stones, the 7 boulders,
    // the 26 motes.
    Pieces {
        host: root
        kind: 0
        rows: 2 * (48 + 3) + 4 * 14
        fragmentShader: Qt.resolvedUrl("qsb/Boulders.qsb")
    }

    Pieces {
        host: root
        kind: 1
        rows: 4 * 7
        fragmentShader: Qt.resolvedUrl("qsb/Boulders.rock.qsb")
    }

    Pieces {
        host: root
        kind: 2
        rows: 4 * 26
        fragmentShader: Qt.resolvedUrl("qsb/Boulders.qsb")
    }
}
