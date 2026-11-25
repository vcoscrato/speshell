import QtQuick
import "common"
import "Christmas.js" as Christmas

// Christmas wallpaper transition: frost creeps over the old wallpaper from the screen's
// edges and corners in feathery fronds, paling it, until the window is frosted over;
// then it thaws from several warm spots, as under breath, its edges wet, onto the new
// wallpaper, crisp once dry.
//
// Where frost reaches and when it thaws is worked out once, into a table
// (WallpaperTransition.frost.frag), that the shader drawing each frame reads.
WallpaperStage {
    id: root

    readonly property real growEnd: 0.85
    readonly property real thawEnd: 1.82
    duration: 1.94

    // Scattered behind the frost: read from a blurred mip.
    outgoingTexture.mipmap: true

    readonly property real seed: Math.random()
    // The warm spots: one to a share of the width, at random heights and starts, as
    // (x, y, start, reach) in fractions of the screen and seconds. The first open as
    // the last frost comes in, the rest just after, some weaker than others.
    readonly property var picks: {
        const n = 5 + (Math.random() < 0.5 ? 1 : 0);
        const order = [...Array(n).keys()].sort(() => Math.random() - 0.5);
        return order.map((slot, i) => [(slot + 0.2 + 0.6 * Math.random()) / n, 0.2 + 0.6 * Math.random(),
                                       0.8 + 0.08 * i + 0.06 * Math.random(), 0.55 + 0.6 * Math.random()]);
    }
    readonly property var spots: root.picks.map(s => Qt.vector4d(s[0] * root.width, s[1] * root.height, s[2],
                                                                 s[3] * root.height))
    // The furthest any point lies from the spots, in their reaches, so the thaw
    // reaches everywhere by thawEnd.
    readonly property real thawScale: {
        let far = 0.1;
        for (let y = 0; y <= 12; y++) {
            for (let x = 0; x <= 20; x++) {
                const px = x / 20 * root.width, py = y / 12 * root.height;
                far = Math.max(far, Math.min(...root.spots.map(s => Math.hypot(px - s.x, 1.6 * (py - s.y)) / s.w)));
            }
        }
        return far;
    }
    readonly property vector4d none: Qt.vector4d(0, 0, 0, 0)
    // The table at the screen's size, but at most 1080 rows.
    readonly property real fieldScale: Math.min(1, 1080 / Math.max(1, root.height))

    ShaderEffect {
        id: frostPass
        width: Math.max(1, Math.ceil(root.width * root.fieldScale))
        height: Math.max(1, Math.ceil(root.height * root.fieldScale))
        blending: false
        property size resolution: Qt.size(root.width, root.height)
        property real seed: root.seed
        property real growEnd: root.growEnd
        property real thawEnd: root.thawEnd
        property real thawScale: root.thawScale
        property vector4d spot0: root.spots[0] ?? root.none
        property vector4d spot1: root.spots[1] ?? root.none
        property vector4d spot2: root.spots[2] ?? root.none
        property vector4d spot3: root.spots[3] ?? root.none
        property vector4d spot4: root.spots[4] ?? root.none
        property vector4d spot5: root.spots[5] ?? root.none
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.frost.qsb")
    }

    ShaderEffectSource {
        id: frostTex
        sourceItem: frostPass
        hideSource: true
        format: ShaderEffectSource.RGBA16F
        textureSize: Qt.size(frostPass.width, frostPass.height)
    }

    ShaderEffectSource {
        id: incomingTex
        sourceItem: root.incoming
        live: false
        mipmap: true
    }

    ShaderEffect {
        anchors.fill: parent
        property var field: frostTex
        property var outgoing: root.outgoingTexture
        property var incoming: incomingTex
        property size resolution: Qt.size(width, height)
        property real time: root.clock.clock
        property real seed: root.seed
        property real thawEnd: root.thawEnd
        property color cIce: Christmas.ice(root.theme)
        property color cSnow: Christmas.snow(root.theme)
        property color cShade: Christmas.snowShade(root.theme)
        property color cGlint: root.theme.text
        fragmentShader: Qt.resolvedUrl("qsb/WallpaperTransition.qsb")
    }
}
