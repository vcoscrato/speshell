import QtQuick
import "common"
import "Bolt.js" as Bolt

// Relâmpago launcher transition, drawn like a cartoon: the launcher races in from
// the left, stretched by its speed, in a streak of glossy red with a bolt decal
// through it, brakes hard, leaving skid marks and a shower of sparks, and squashes
// to a stop with a comic starburst, in puffs of tire smoke, as lightning strikes it
// twice. While open, speed lines trail off behind it in gusts, electricity crackles
// along its border, and now and then a bolt strikes it, bursting where it lands and
// sending a charge racing round the border.
// Closing, it squats, stretches, and tears away to the right on two trails of fire.
LauncherStage {
    id: root

    // ── Choreography (seconds) ──────────────────────────────
    readonly property real arriveTime: 0.5     // racing in to the stop
    readonly property real settleTime: 0.3     // rocking back on its springs
    enterTime: arriveTime + settleTime
    exitTime: 0.42
    tailTime: 0.18      // the fire burning out

    // The drive, sampled each tick.
    property real driveX: -root.farLeft
    property real speed: 0
    property real lean: 0
    // Squash and stretch: > 0 stretched along x, < 0 squashed; a spring toward
    // how fast it goes, kicked as it stops and launches.
    property real stretch: 0
    property real stretchVel: 0
    property real travel: 0
    property real skidAge: -1                  // s since it stopped; < 0 before
    property real fireAge: -1                  // s since it tore away; < 0 before
    property real sparkOwed: 0
    property bool primed: false
    property real nextStrike: 1.6              // s until lightning strikes the open panel
    // The last two bolts to strike the border: where, s since they landed (< 0
    // before, long past at first), and a seed; strikes take turns between them.
    property vector4d hitA: Qt.vector4d(0, 0, 9, 0)
    property vector4d hitB: Qt.vector4d(0, 0, 9, 0)
    property bool hitTurn: false
    // Whether it had stopped, and was leaving, as of the last step.
    property bool wasStopped: false
    property bool wasLeaving: false

    readonly property real arriveEnd: arriveTime / (arriveTime + settleTime)
    readonly property real farLeft: panelRect.x + panelRect.width + 140
    readonly property real farRight: width - panelRect.x + 140
    readonly property real floorY: panelRect.y + panelRect.height
    // The rear tires, about a fifth of the way along the panel.
    readonly property real rear: panelRect.x + driveX + panelRect.width * 0.2

    function span(x, a, b) { return Math.max(0, Math.min(1, (x - a) / (b - a))); }

    // Where the drive puts the panel, from rest, for the current progress.
    function position() {
        if (root.leave > 0)
            return root.farRight * Math.pow(root.leave, 2.4);
        if (root.enter < root.arriveEnd)
            return -root.farLeft * Math.pow(1 - root.enter / root.arriveEnd, 3.2);
        // Past its mark a little as it skids, then back.
        const s = (root.enter - root.arriveEnd) / (1 - root.arriveEnd);
        return 16 * Math.sin(Math.PI * Math.min(1, s * 1.15)) * (1 - s);
    }

    onAdvanced: dt => {
        const x = root.position();
        if (!root.primed) {
            root.primed = true;
            root.driveX = x;
        }
        const v = (x - root.driveX) / dt;
        const accel = (v - root.speed) / dt;
        root.driveX = x;
        root.speed = v;
        // Leans into braking and back from acceleration, settling by the end.
        const want = Math.max(-14, Math.min(14, -accel * 0.0009)) * (1 - root.span(root.enter, 0.85, 1) * (root.leave > 0 ? 0 : 1));
        root.lean += (want - root.lean) * Math.min(1, dt * 18);
        if (root.enter >= 1 && root.leave === 0)
            root.lean = 0;
        const stretchTo = Math.min(0.2, Math.abs(v) / 9000);
        root.stretchVel += (380 * (stretchTo - root.stretch) - 13 * root.stretchVel) * dt;
        root.stretch = Math.max(-0.2, Math.min(0.25, root.stretch + root.stretchVel * dt));
        root.travel += dt * (650 + Math.abs(v) * 0.5);

        if (root.skidAge >= 0)
            root.skidAge += dt;
        if (root.fireAge >= 0)
            root.fireAge += dt;
        if (root.hitA.z < 1)
            root.hitA = Qt.vector4d(root.hitA.x, root.hitA.y, root.hitA.z + dt, root.hitA.w);
        if (root.hitB.z < 1)
            root.hitB = Qt.vector4d(root.hitB.x, root.hitB.y, root.hitB.z + dt, root.hitB.w);
        // Sparks off the rear while braking hard.
        if (root.leave === 0 && root.enter < root.arriveEnd && x > -320) {
            root.sparkOwed += Math.abs(v) * dt;
            while (root.sparkOwed > 26) {
                root.sparkOwed -= 26;
                bits.emit(bits.spark, { x: root.rear, y: root.floorY + bits.rnd(4, 14), vx: bits.rnd(-260, -60),
                                        vy: bits.rnd(-200, -40), gravity: 700, life: bits.rnd(0.3, 0.5),
                                        size: Math.round(bits.rnd(16, 24)), orient: true });
            }
        }
        // Now and then while open, lightning strikes it.
        if (root.active && root.enter >= 1 && root.leave === 0) {
            root.nextStrike -= dt;
            if (root.nextStrike <= 0) {
                root.nextStrike = bits.rnd(2.2, 4.2);
                root.strikeBorder(0);
            }
        }
        if (!root.wasStopped && root.enter >= root.arriveEnd * 0.94 && root.leave === 0)
            root.stopped();
        if (!root.wasLeaving && root.leave > 0 && !root.active)
            root.launched();
        root.wasStopped = root.enter >= root.arriveEnd * 0.94;
        root.wasLeaving = root.leave > 0;
    }

    // Skidded to its mark: smoke from the tires, sparks off the front, and lightning.
    function stopped() {
        root.skidAge = 0;
        root.stretchVel -= 4.5;
        const x0 = root.panelRect.x, w = root.panelRect.width;
        for (let i = 0; i < 6; i++)
            bits.emit(bits.smoke, { x: x0 + w * bits.rnd(-0.08, 0.06), y: root.floorY + bits.rnd(8, 18),
                                    vx: bits.rnd(-220, -80), vy: bits.rnd(-45, -10), drag: 1.8,
                                    life: bits.rnd(1.0, 1.4), size: Math.round(bits.rnd(70, 120)), delay: i * 0.035 });
        for (let i = 0; i < 4; i++)
            bits.emit(bits.smoke, { x: x0 + w * bits.rnd(0.9, 1.04), y: root.floorY + bits.rnd(8, 16),
                                    vx: bits.rnd(50, 140), vy: bits.rnd(-40, -10), drag: 1.8,
                                    life: bits.rnd(0.8, 1.1), size: Math.round(bits.rnd(50, 84)), delay: 0.05 + i * 0.04 });
        for (let i = 0; i < 10; i++)
            bits.emit(bits.spark, { x: x0 + w * bits.rnd(0.78, 0.95), y: root.floorY + 6, vx: bits.rnd(60, 320),
                                    vy: bits.rnd(-260, -60), gravity: 800, life: bits.rnd(0.35, 0.6),
                                    size: Math.round(bits.rnd(18, 28)), orient: true });
        // A comic impact off its front, behind it, and a glint on its paint.
        behind.emit(behind.star, { x: x0 + w + 6, y: root.floorY - root.panelRect.height * 0.35, life: 0.32,
                                   size: Math.round(Math.min(200, root.panelRect.height * 0.55)), angle: bits.rnd(0, 360) });
        bits.emit(bits.glint, { x: x0 + 18, y: root.panelRect.y + 6, life: 0.45, size: 30, delay: 0.12 });
        // Lightning strikes it twice as it stops.
        const left = Math.random() < 0.5;
        root.strikeBorder(0.04, left ? -0.08 : 0.55, left ? 0.45 : 1.08);
        root.strikeBorder(bits.rnd(0.18, 0.26), left ? 0.55 : -0.08, left ? 1.08 : 0.45);
    }

    // A bolt striking down from the sky onto a random point along the panel's top,
    // or a top corner, after `delay` s. It lands bare, and the track draws where it hits.
    function strikeBorder(delay, from, to) {
        const r = root.panelRect, k = root.panelRadius * 0.29;
        const f = bits.rnd(from === undefined ? -0.08 : from, to === undefined ? 1.08 : to);
        // Past either end of the top it lands on the corner's curve, slanting in from that side.
        const x = r.x + Math.max(k, Math.min(r.width - k, r.width * f));
        const y = r.y + (f < 0 || f > 1 ? k : 0);
        const angle = (f < 0 ? -30 : f > 1 ? 30 : 0) + bits.rnd(-18, 18);
        const life = bits.rnd(0.5, 0.62);
        bits.emit(bits.bareStrike, { x: x, y: y, life: life, size: Math.round(bits.rnd(520, 720)),
                                     angle: angle, delay: delay });
        // It lands a few hundredths of a second into its life.
        const land = delay + life * 0.07;
        const hit = Qt.vector4d(x, y, -land, Math.random());
        if (root.hitTurn)
            root.hitB = hit;
        else
            root.hitA = hit;
        root.hitTurn = !root.hitTurn;
        const out = angle * Math.PI / 180;
        for (let i = 0; i < 4; i++) {
            const a = out - Math.PI / 2 + bits.rnd(-1.1, 1.1);
            const v = bits.rnd(120, 260);
            bits.emit(bits.spark, { x: x, y: y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, gravity: 700,
                                    life: bits.rnd(0.3, 0.5), size: Math.round(bits.rnd(16, 24)), orient: true,
                                    delay: land });
        }
    }

    // Tore away: a burnout, smoke and sparks flung back off the rear.
    function launched() {
        root.fireAge = 0;
        root.stretchVel -= 3;
        root.skidAge = Math.max(root.skidAge, 0.8);
        for (let i = 0; i < 6; i++)
            bits.emit(bits.smoke, { x: root.rear + bits.rnd(-30, 10), y: root.floorY + bits.rnd(0, 12),
                                    vx: bits.rnd(-140, -40), vy: bits.rnd(-60, -10), drag: 1.8,
                                    life: bits.rnd(0.5, 0.7), size: Math.round(bits.rnd(56, 90)), delay: i * 0.02 });
        for (let i = 0; i < 8; i++)
            bits.emit(bits.spark, { x: root.rear, y: root.floorY + 8, vx: bits.rnd(-340, -100), vy: bits.rnd(-220, -40),
                                    gravity: 800, life: bits.rnd(0.3, 0.5), size: Math.round(bits.rnd(18, 26)), orient: true });
    }

    // ── Around the panel: speed lines, crackle, strikes, skid marks, and fire ──
    // Over the whole screen while it races; once it stands, only round the panel and
    // the dashes trailing behind it, which fade out within 700 px.
    ShaderEffect {
        readonly property bool standing: root.leave === 0 && calm >= 1
        readonly property real fromX: Math.max(0, root.panelRect.x - 700)
        x: standing ? fromX : 0
        y: standing ? root.panelRect.y - 50 : 0
        width: standing ? root.panelRect.x + root.panelRect.width + 50 - fromX : root.width
        height: standing ? root.panelRect.height + 100 : root.height
        visible: lines > 0 || skid > 0 || fire > 0 || root.hitA.z < 0.75 || root.hitB.z < 0.75
        property point offset: Qt.point(x, y)
        property size resolution: Qt.size(width, height)
        property real screenWidth: root.width
        property real time: root.clock.simTime
        property rect rect: Qt.rect(root.panelRect.x + root.driveX, root.panelRect.y, root.panelRect.width, root.panelRect.height)
        property real radius: root.panelRadius
        property real lines: root.span(root.enter, 0, 0.12) * (1 - root.span(root.leave, 0.5, 1))
        // Once it stands, the dashes draw back behind it.
        property real calm: root.leave > 0 ? 1 - root.span(root.leave, 0, 0.3) : root.span(root.enter, root.arriveEnd, 1)
        property real spread: 1 + Math.min(2.5, Math.abs(root.speed) / 900)
        property real travel: root.travel % 1e6
        property real arcs: root.span(root.enter, root.arriveEnd, 1) * (1 - root.span(root.leave, 0, 0.15))
        property real skid: root.skidAge < 0 ? (root.driveX > -300 && root.leave === 0 ? 1 : 0)
                                             : Math.max(0, 1 - root.skidAge / 1.4)
        property point skidSpan: Qt.point(root.panelRect.x - 260, root.rear)
        property real fire: root.fireAge < 0 ? 0 : Math.max(0, Math.min(1, 1 - (root.fireAge - 0.18) / 0.42))
        property point fireSpan: Qt.point(root.panelRect.x + root.panelRect.width * 0.2, root.rear)
        property real trackY: root.floorY
        property vector4d hitA: root.hitA
        property vector4d hitB: root.hitB
        property color cLine: root.theme.text
        property color cCore: Bolt.core(root.theme)
        property color cGlow: Bolt.glow(root.theme)
        property color cEdge: Bolt.edge(root.theme)
        property color cPaint: Bolt.paint(root.theme)
        property color cRubber: Bolt.rubber(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.track.qsb")
    }

    // Under the racing panel: the starburst it stops in. Shown only while the panel
    // is drawn here, since the real one lies under this whole item.
    Bits {
        id: behind
        anchors.fill: parent
        visible: root.capturing
        theme: root.theme
    }

    // ── The panel, racing; otherwise the real panel shows ──
    ShaderEffect {
        visible: root.capturing && root.panel !== null
        x: 0
        y: root.panelRect.y - 24 - root.panelRect.height * 0.25
        width: root.width
        height: root.panelRect.height * 1.25 + 48
        property var source: root.panelTexture
        property point origin: Qt.point(x, y)
        property size resolution: Qt.size(width, height)
        property rect rect: root.panelRect
        property real offset: root.driveX
        property real smear: Math.min(Math.abs(root.speed) * 0.05, 420)
        property real dir: root.speed >= 0 ? 1 : -1
        property real lean: root.lean
        // Settled by the time the real panel shows again.
        property real stretch: root.stretch * (root.leave > 0 ? 1 : 1 - root.span(root.enter, 0.85, 1))
        property real heat: Math.min(1, Math.abs(root.speed) / 1600)
        property color cPaint: Bolt.paint(root.theme)
        property color cGlow: Bolt.glow(root.theme)
        property color cEdge: Bolt.edge(root.theme)
        property color cCore: Bolt.core(root.theme)
        property color cRubber: Bolt.rubber(root.theme)
        fragmentShader: Qt.resolvedUrl("qsb/LauncherTransition.qsb")
    }

    Bits {
        id: bits
        anchors.fill: parent
        theme: root.theme
    }
}
