import QtQuick
import "Flame.js" as Flame

// Cel-shaded flames from a quarter-resolution fluid simulation. Fuel comes from a
// simmering rim around `panelRect` and from the burn front at `burnR` around `origin`.
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

    property var theme: null
    property color core: Flame.core(theme)
    property color mid: Flame.mid(theme)
    property color outer: Flame.outer(theme)
    property color edge: Flame.edge(theme)

    property real steppedTime: 0
    property bool stepping: false

    // One step at a time: time that passes while a step renders goes into the next.
    function step() {
        var dt = Math.min(0.1, root.time - root.steppedTime);
        if (root.stepping || dt <= 0)
            return;
        sim.dt = dt;
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
        property size resolution: Qt.size(root.width, root.height)
        property rect panel: root.panelRect
        property real radius: root.radius
        property point origin: root.origin
        property real burnR: root.burnR
        property real fieldScale: root.fieldScale
        property real clearBehind: root.clearBehind ? 1 : 0
        fragmentShader: Qt.resolvedUrl("qsb/Flames.sim.qsb")
    }

    ShaderEffect {
        anchors.fill: parent
        property var state: simState
        property real time: root.time
        property size resolution: Qt.size(width, height)
        property color cCore: root.core
        property color cMid: root.mid
        property color cOuter: root.outer
        property color cEdge: root.edge
        fragmentShader: Qt.resolvedUrl("qsb/Flames.qsb")
    }
}
