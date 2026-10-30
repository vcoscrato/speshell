import QtQuick
import "Stone.js" as Stone
import "common"

// Earth wallpaper transition: a blow strikes the old wallpaper just below the
// middle; cracks race out from it and branch, and the shards break loose one by one,
// small rubble first and broad slabs last, dropping away in dust.
//
// What stands is drawn over the whole screen; the falling shards, their dust, and the
// chips each on a quad of its own, so that a pixel pays only for the pieces over it.
// Everything about a shard or a point of the screen that does not change as it plays
// is worked out once, into the float tables and maps below.
Item {
    id: root

    // ── Speshell effects API v1 ────────────────────────────────
    property Item outgoing: null
    // The active palette, as Theme.qml names it.
    property var theme: null
    signal finished()

    // The last shards break loose at about 1.65 s and take up to 0.75 s to fall and settle.
    readonly property real duration: 2.4

    property real elapsed: 0
    property bool done: false
    readonly property point center: Qt.point(width * 0.5, height * 0.56)
    readonly property real reach: Math.sqrt(Math.pow(width * 0.5, 2) + Math.pow(height * 0.56, 2))

    readonly property color cCrack: Stone.tone(root.theme, "crust", 0.15, "#2a2219")
    readonly property color cLip: Stone.tone(root.theme, "text", 0.3, "#d8c8a8")
    readonly property color cDust: Stone.tone(root.theme, "subtextBright", 0.3, "#cdbb9a")
    readonly property color cDustShade: Stone.tone(root.theme, "subtext", 0.45, "#9c8a6c")

    // The sizes follow Shatter.glsl: KX cells along a ray by N around the impact, CELL
    // texels each, and the chip grid's CHIP_G px squares, from two before the screen
    // to two past it, CHIP texels each.
    readonly property int cellCount: 32 * 30
    readonly property size chipGrid: Qt.size(Math.ceil(root.width / 64) + 4, Math.ceil(root.height / 64) + 4)

    // For the pieces, which cannot see these ids.
    readonly property var outgoingTable: outgoingTex
    readonly property var cellsTable: cellsTex
    readonly property var chipsTable: chipsTex
    readonly property var cellMapTable: cellMapTex
    readonly property var crackMapTable: crackMapTex
    readonly property var orderTable: orderTex

    EffectClock {
        onAdvanced: function(dt) {
            root.elapsed += dt;
            if (!root.done && root.elapsed >= root.duration) {
                root.done = true;
                // Speshell may destroy this item inside the signal, so nothing may follow it.
                root.finished();
            }
        }
    }

    ShaderEffectSource {
        id: outgoingTex
        sourceItem: root.outgoing
        hideSource: true
        live: false
    }

    // ── Worked out once ──

    // A float table drawn by a pass that is never shown itself.
    component Table: ShaderEffectSource {
        hideSource: true
        smooth: false
        format: ShaderEffectSource.RGBA32F
        textureSize: sourceItem ? Qt.size(sourceItem.width, sourceItem.height) : Qt.size(1, 1)
    }

    // Each cell's site and shard, when the shard breaks loose and how it falls.
    ShaderEffect {
        id: cellsPass
        width: 32 * 3
        height: 30
        blending: false
        property point center: root.center
        property real reach: root.reach
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.cells.qsb")
    }

    Table {
        id: cellsTex
        sourceItem: cellsPass
    }

    // Each chip: where it starts, when it is flung, how it flies, and its color.
    ShaderEffect {
        id: chipsPass
        width: root.chipGrid.width * 3
        height: root.chipGrid.height
        blending: false
        property var source: outgoingTex
        property size resolution: Qt.size(root.width, root.height)
        property point center: root.center
        property real reach: root.reach
        property size grid: root.chipGrid
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.chips.qsb")
    }

    Table {
        id: chipsTex
        sourceItem: chipsPass
    }

    // The order the shards are drawn in: each cell's rank, then the cell at each rank.
    ShaderEffect {
        id: rankPass
        width: root.cellCount
        height: 1
        blending: false
        property var cells: cellsTex
        property var ranks: cellsTex
        property point center: root.center
        property real reach: root.reach
        property real which: 0
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.order.qsb")
    }

    Table {
        id: rankTex
        sourceItem: rankPass
    }

    ShaderEffect {
        id: orderPass
        width: root.cellCount
        height: 1
        blending: false
        property var cells: cellsTex
        property var ranks: rankTex
        property point center: root.center
        property real reach: root.reach
        property real which: 1
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.order.qsb")
    }

    Table {
        id: orderTex
        sourceItem: orderPass
    }

    // Each screen point's shard, and the crack beside it: the shard is looked up
    // exactly, the crack smoothly, as the falling shards turn.
    ShaderEffect {
        id: cellMapPass
        anchors.fill: parent
        blending: false
        property real which: 0
        property var cells: cellsTex
        property size resolution: Qt.size(width, height)
        property point center: root.center
        property real reach: root.reach
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.map.qsb")
    }

    ShaderEffectSource {
        id: cellMapTex
        sourceItem: cellMapPass
        hideSource: true
        smooth: false
        format: ShaderEffectSource.RGBA16F
    }

    ShaderEffect {
        id: crackMapPass
        anchors.fill: parent
        blending: false
        property real which: 1
        property var cells: cellsTex
        property size resolution: Qt.size(width, height)
        property point center: root.center
        property real reach: root.reach
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.map.qsb")
    }

    ShaderEffectSource {
        id: crackMapTex
        sourceItem: crackMapPass
        hideSource: true
        format: ShaderEffectSource.RGBA16F
    }

    // ── Drawn each frame, back to front ──

    // What still stands, with its cracks.
    ShaderEffect {
        anchors.fill: parent
        property var source: outgoingTex
        property var cells: cellsTex
        property var cellMap: cellMapTex
        property var crackMap: crackMapTex
        property size resolution: Qt.size(width, height)
        property point center: root.center
        property real time: root.elapsed
        property real reach: root.reach
        property color cCrack: root.cCrack
        property color cLip: root.cLip
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.qsb")
    }

    // A strip of pieces (Shards.glsl): one diamond for each of `slots`.
    component Pieces: ShaderEffect {
        required property Item host
        property real kind: 0
        property real slots: host.cellCount
        anchors.fill: parent
        mesh: GridMesh {
            resolution: Qt.size(1, 3 * slots - 1)
        }
        property var source: host.outgoingTable
        property var cells: host.cellsTable
        property var chips: host.chipsTable
        property var cellMap: host.cellMapTable
        property var crackMap: host.crackMapTable
        property var order: host.orderTable
        property size resolution: Qt.size(width, height)
        property point center: host.center
        property real time: host.elapsed
        property real reach: host.reach
        property size chipGrid: host.chipGrid
        property color cCrack: host.cCrack
        property color cLip: host.cLip
        property color cDust: host.cDust
        property color cDustShade: host.cDustShade
        vertexShader: Qt.resolvedUrl("qsb/WallpaperTransition.vert.qsb")
    }

    // The dust the shards crumble into, behind the ones still falling.
    Pieces {
        host: root
        kind: 0
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.dust.qsb")
    }

    // The falling shards.
    Pieces {
        host: root
        kind: 1
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.shard.qsb")
    }

    // Chips of the old wallpaper flung up from the cracks as the front passes.
    Pieces {
        host: root
        kind: 2
        slots: root.chipGrid.width * root.chipGrid.height
        visible: root.elapsed < 1.6
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.chip.qsb")
    }

    // The crater: a burst of dust at the point of impact.
    ShaderEffect {
        x: root.center.x - 152
        y: root.center.y - 176
        width: 304
        height: 328
        visible: root.elapsed < 0.9
        property rect rect: Qt.rect(x, y, width, height)
        property point center: root.center
        property real time: root.elapsed
        property real reach: root.reach
        property color cDust: root.cDust
        property color cDustShade: root.cDustShade
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.crater.qsb")
    }
}
