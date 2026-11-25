import QtQuick
import "common/Colors.js" as Colors
import "Flame.js" as Flame

// Cel-shaded flames from a quarter-resolution fluid simulation. Fuel comes from a
// simmering rim along `panelRect`'s top and from the burn front at `burnR` around `origin`,
// all in the parent's coordinates, over whatever part of the parent this item covers.
// The simulation steps once per rendered frame by the `time` passed since its last
// step, so it runs at the same pace at any clock speed, frame rate, or display rate.
Item {
    id: root

    property real time: 0
    property real emit: 0          // 0..1 rim flames around panelRect
    property real frontFuel: 0     // 0..1 flames along the burn front
    property rect panelRect
    property real radius: 4
    property point origin
    property real burnR: -1
    property real fieldScale: 1
    property bool clearBehind: true   // keep flames off the panel once the front has passed
    property real trail: 0            // px behind the front past which flames die fast; 0: no limit
    property bool layered: false      // a deeper row of rim flames behind the front one
    property real sparse: 0           // 0..1 the front burns in separate jets however small it is
    property bool kindle: false       // the rim catches only where the front has passed
    property real douse: 0            // 0..1 flames outside the panel burn out faster

    property var theme: Colors.fallback
    property color core: Flame.core(theme)
    property color mid: Flame.mid(theme)
    property color outer: Flame.outer(theme)
    property color edge: Flame.edge(theme)
    property color back: Colors.mix(edge, outer, 0.3)
    property color backHot: Colors.mix(outer, mid, 0.3)

    property real steppedTime: 0
    property real steppedBurnR: -1
    property bool stepping: false

    // One step at a time: time that passes while a step renders goes into the next.
    function step() {
        const dt = Math.min(0.1, root.time - root.steppedTime);
        if (root.stepping || dt <= 0)
            return;
        sim.dt = dt;
        // How far the front moved since the last step: the step lays fuel over all of it.
        sim.burnStep = Math.max(0, Math.min(150, root.burnR - root.steppedBurnR));
        root.steppedBurnR = root.burnR;
        root.steppedTime = root.time;
        root.stepping = true;
        simState.scheduleUpdate();
    }

    onTimeChanged: root.step()

    ShaderEffectSource {
        id: simState
        sourceItem: sim
        recursive: true
        live: false
        hideSource: true
        smooth: true
        format: ShaderEffectSource.RGBA16F
        onScheduledUpdateCompleted: {
            root.stepping = false;
            root.step();
        }
    }

    ShaderEffect {
        id: sim
        width: Math.max(1, Math.round(root.width / 4))
        height: Math.max(1, Math.round(root.height / 4))
        property var state: simState
        property real time: root.time
        property real dt: 0
        property real emit: root.emit
        property real frontFuel: root.frontFuel
        property point offset: Qt.point(root.x, root.y)
        property size resolution: Qt.size(root.width, root.height)
        property rect panel: root.panelRect
        property real radius: root.radius
        property point origin: root.origin
        property real burnR: root.burnR
        property real burnStep: 0
        property real fieldScale: root.fieldScale
        property real clearBehind: root.clearBehind ? 1 : 0
        property real trail: root.trail
        property real layered: root.layered ? 1 : 0
        property real sparse: root.sparse
        property real kindle: root.kindle ? 1 : 0
        property real douse: root.douse
        fragmentShader: Qt.resolvedUrl("qsb/Flames.sim.qsb")
    }

    ShaderEffect {
        anchors.fill: parent
        property var state: simState
        property real time: root.time
        property point offset: Qt.point(root.x, root.y)
        property size resolution: Qt.size(width, height)
        property color cCore: root.core
        property color cMid: root.mid
        property color cOuter: root.outer
        property color cEdge: root.edge
        property color cBack: root.back
        property color cBackHot: root.backHot
        fragmentShader: Qt.resolvedUrl("qsb/Flames.qsb")
    }
}
