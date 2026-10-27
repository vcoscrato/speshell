import QtQuick

// A pool of short-lived particles for small effects: spawn() starts one at a point with
// a velocity and a lifetime, and it flies under gravity and drag, spinning, bouncing
// off a floor if it has one, until its life runs out. The pool's EffectClock exists
// only while a particle lives, so an idle pool costs nothing.
//
// The delegate is an Item, typically a small ShaderEffect, with an `age` property
// (0..1 over its life) and any others spawn() sets through `props`. The pool sizes it,
// centers it on the particle, and turns it. Spent items are reused.
Item {
    id: root

    property Component delegate: null
    property real gravity: 0      // px/s², downward
    property int capacity: 64     // spawns past this many live particles are dropped
    // Items made ahead, a few each frame, so the first effects need not stop to make them.
    property int prewarm: 12

    property int live: 0
    property var parts: []

    // Fields of `p` (all optional but x, y, and life):
    //   x, y          start, in this item's coordinates
    //   vx, vy        velocity, px/s
    //   life          seconds
    //   delay         seconds before it appears
    //   size          px, the delegate's width and height (default 16)
    //   gravity       px/s², replacing the pool's
    //   drag          share of the velocity lost per second
    //   angle, spin   degrees and degrees per second
    //   orient        true: turn along the velocity instead
    //   floor, bounce y it bounces off (keeping `bounce` of its speed, default 0.35)
    //   props         properties set on the delegate when it spawns
    function spawn(p) {
        if (!root.delegate || root.live >= root.capacity)
            return;
        var part = null;
        for (var i = 0; i < root.parts.length; i++) {
            if (!root.parts[i].alive) {
                part = root.parts[i];
                break;
            }
        }
        if (!part) {
            part = { item: root.delegate.createObject(root, { visible: false }) };
            if (!part.item)
                return;
            root.parts.push(part);
        }
        part.x = p.x;
        part.y = p.y;
        part.vx = p.vx || 0;
        part.vy = p.vy || 0;
        part.life = Math.max(0.01, p.life);
        part.age = -(p.delay || 0);
        part.gravity = p.gravity !== undefined ? p.gravity : root.gravity;
        part.drag = p.drag || 0;
        part.angle = p.angle || 0;
        part.spin = p.spin || 0;
        part.orient = !!p.orient;
        part.floor = p.floor !== undefined ? p.floor : Infinity;
        part.bounce = p.bounce !== undefined ? p.bounce : 0.35;
        part.alive = true;
        var item = part.item;
        item.width = p.size || 16;
        item.height = p.size || 16;
        item.age = 0;
        for (var key in (p.props || {}))
            item[key] = p.props[key];
        root.place(part);
        root.live++;
    }

    function place(part) {
        var item = part.item;
        item.visible = part.age >= 0;
        item.x = part.x - item.width / 2;
        item.y = part.y - item.height / 2;
        item.rotation = part.orient && (part.vx !== 0 || part.vy !== 0)
            ? Math.atan2(part.vy, part.vx) * 180 / Math.PI : part.angle;
        item.age = Math.max(0, Math.min(1, part.age / part.life));
    }

    function step(dt) {
        for (var i = 0; i < root.parts.length; i++) {
            var part = root.parts[i];
            if (!part.alive)
                continue;
            part.age += dt;
            if (part.age >= part.life) {
                part.alive = false;
                part.item.visible = false;
                root.live--;
                continue;
            }
            if (part.age >= 0) {
                var keep = Math.exp(-part.drag * dt);
                part.vx *= keep;
                part.vy = part.vy * keep + part.gravity * dt;
                part.x += part.vx * dt;
                part.y += part.vy * dt;
                part.angle += part.spin * dt;
                if (part.y > part.floor && part.vy > 0) {
                    part.y = part.floor;
                    part.vy *= -part.bounce;
                    part.vx *= 0.7;
                    part.spin *= 0.6;
                }
            }
            root.place(part);
        }
    }

    function warm() {
        if (!root.delegate || root.parts.length >= root.prewarm)
            return;
        var incubator = root.delegate.incubateObject(root, { visible: false });
        // Null once the effect is being torn down, as on a theme change.
        if (!incubator)
            return;
        var keep = function() {
            if (incubator.status === Component.Ready && root.parts.length < root.capacity)
                root.parts.push({ item: incubator.object, alive: false });
            else if (incubator.object)
                incubator.object.destroy();
            if (incubator.status !== Component.Error)
                Qt.callLater(root.warm);
        };
        if (incubator.status === Component.Loading)
            incubator.onStatusChanged = keep;
        else
            keep();
    }

    Component.onCompleted: root.warm()

    Loader {
        active: root.live > 0
        sourceComponent: Component {
            EffectClock {
                // Emitted last in the tick, so the last particle dying may destroy this.
                onAdvanced: function(dt) { root.step(dt); }
            }
        }
    }
}
