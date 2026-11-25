#version 440
#extension GL_GOOGLE_include_directive : enable
// Fits each piece of the strip (LauncherTransition.decor.glsl) where it is now. The
// string runs round the border from where the top-left corner starts (sigma = 0),
// clockwise: a run along the top, clipped to the edge, then swags drooping outward
// round the rest, each lopsided toward the ground. It is hung one run or swag at a
// time: the free end is carried to the next hook, the wire sagging behind it, and
// springs into its swag when hooked; then its bulbs light down the swag. Closing, the
// hooks let go in turn and the string drops away. Snow falls round the panel at three
// depths, each flake drifting with the wind and swaying, fading out away from it.
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 p;
layout(location = 1) out vec4 piece;
layout(location = 2) out vec4 shape;
layout(location = 3) out vec4 look;     // x: kind (0 flake, 1 wire, 2 bulb, 3 drift, 4 glow, 5 puff)
#define VERTEX_SHADER
#include "LauncherTransition.decor.glsl"

const float BASE = 2.6;     // px from the edge to the wire's middle
const float HW = 2.6;       // px, half the wire's ribbon

float perim() { return rrPerimeter(halfSize(), rad()); }

// The border at sigma, relative to the center, and its outward normal.
vec2 edge(float sg) {
    vec2 h = halfSize();
    float r = rad();
    return rrPoint(sg + 4.0 * (h.x - r) + 4.0 * (h.y - r) + 4.712389 * r, h, r);
}

vec2 outward(float sg) {
    vec2 t = edge(sg + 0.5) - edge(sg - 0.5);
    return normalize(vec2(t.y, -t.x) + 1e-6);
}

float topLen() { return 2.0 * (halfSize().x - rad()) + PI * rad(); }

// Run or swag k: where it starts, and its length along the border.
void segment(float k, out float s0, out float len) {
    if (k < u.topRuns) {
        len = topLen() / u.topRuns;
        s0 = k * len;
    } else {
        len = (perim() - topLen()) / u.swags;
        s0 = topLen() + (k - u.topRuns) * len;
    }
}

float segmentOf(float sg) {
    float top = topLen();
    if (sg < top)
        return min(u.topRuns - 1.0, floor(sg / (top / u.topRuns)));
    return u.topRuns + clamp(floor((sg - top) / ((perim() - top) / u.swags)), 0.0, u.swags - 1.0);
}

// How far along the border the string is hung: the free end is carried from hook to
// hook, pausing at each.
float laid() {
    float t = (u.open - u.hangStart) / u.hangGap;
    if (t <= 0.0)
        return 0.0;
    if (t >= u.topRuns + u.swags)
        return perim();
    float s0, len;
    segment(floor(t), s0, len);
    return s0 + len * smoothstep(0.0, 1.0, fract(t));
}

// How far out from the edge the wire hangs at sigma, with its free end at front.
float wireOut(float sg, float front) {
    float k = segmentOf(sg);
    float s0, len;
    segment(k, s0, len);
    float span = min(front, s0 + len) - s0;
    if (k < u.topRuns || span <= 0.0)
        return BASE;
    float depth = mix(8.0, 15.0, hash(vec2(k, 3.1))) * clamp(len / 115.0, 0.55, 1.3);
    // Lopsided: its lowest point slips toward the ground on the sides.
    vec2 tm = edge(s0 + 0.5 * len + 0.5) - edge(s0 + 0.5 * len - 0.5);
    float skew = exp(0.5 * tm.y + 0.4 * (hash(vec2(k, 5.7)) - 0.5));
    float f = clamp((sg - s0) / span, 0.0, 1.0);
    // Held up while carried, it springs into its swag once hooked.
    float since = u.open - u.hangStart - (k + 1.0) * u.hangGap;
    float hold = since < 0.0 ? 0.8 * span / len : 1.0 - 0.2 * exp(-5.0 * since) * cos(10.0 * since);
    return BASE + depth * hold * sin(PI * pow(f, skew));
}

// Closing, hook j lets go in turn: how far it has fallen (px) and for how long (s).
vec2 hookFall(float j) {
    float tau = max(0.0, u.leave - 0.02 - 0.3 * j / (u.topRuns + u.swags)) * u.exitTime;
    return vec2(1400.0 * tau * tau, tau);
}

vec2 fallAt(float sg) {
    float k = segmentOf(sg);
    float s0, len;
    segment(k, s0, len);
    return mix(hookFall(k), hookFall(k + 1.0), clamp((sg - s0) / len, 0.0, 1.0));
}

vec2 wireAt(float sg, float front) {
    return center() + edge(sg) + outward(sg) * wireOut(sg, front) + vec2(0.0, fallAt(sg).x);
}

// Bulb i: where it leaves the wire, the way it points, and its state: size, how
// brightly it is lit (with the flash of lighting up), its color, and what is left of it.
bool bulb(float i, float front, out vec2 b, out vec2 dir, out vec4 state) {
    b = vec2(0.0);
    dir = vec2(0.0, 1.0);
    state = vec4(0.0);
    if (i >= u.bulbs)
        return false;
    float sg = (i + 0.5 + 0.3 * (hash(vec2(i, 1.9)) - 0.5)) * perim() / u.bulbs;
    if (front < sg + 0.5)
        return false;
    b = wireAt(sg, front);
    vec2 t = normalize(wireAt(sg + 0.6, front) - wireAt(sg - 0.6, front) + 1e-6);
    vec2 out_ = vec2(t.y, -t.x);
    // Standing up off the top, hanging outward and down elsewhere.
    dir = sg < topLen() ? out_ : normalize(out_ + vec2(0.0, 0.85));
    vec2 fall = fallAt(sg);
    dir = normalize(mix(dir, vec2(0.0, 1.0), smoothstep(0.0, 0.18, fall.y)) + 1e-6);
    dir = rot(dir, 0.42 * (hash(vec2(i, 2.3)) - 0.5) + 9.0 * (hash(vec2(i, 6.1)) - 0.5) * fall.y);
    float k = segmentOf(sg);
    float s0, len;
    segment(k, s0, len);
    float on = u.hangStart + (k + 1.0) * u.hangGap + 0.05 + 0.3 * (sg - s0) / len;
    float lit = smoothstep(on, on + 0.16, u.open);
    float flash = 1.0 + 0.7 * lit * exp(-4.0 * max(0.0, u.open - on - 0.16));
    float w = mix(0.6, 1.4, hash(vec2(i, 7.3)));
    float tw = 0.86 + 0.14 * sin(u.time * w + TAU * hash(vec2(i, 8.9)))
             - 0.3 * smoothstep(0.93, 1.0, sin(u.time * w * 0.37 + TAU * hash(vec2(i, 4.4))));
    // Unplugged as its hook lets go.
    lit *= 1.0 - smoothstep(0.0, 0.05, fall.y);
    state = vec4(mix(0.9, 1.08, hash(vec2(i, 9.7))), lit * tw * flash, mod(i, 5.0), 1.0 - smoothstep(0.12, 0.28, fall.y));
    return true;
}

// The corner of a quadrilateral for this row: role 0 is a, role 1 b or c by column,
// role 2 d, with a and d opposite.
vec2 corner(float role, vec2 a, vec2 b, vec2 c, vec2 d) {
    if (role < 0.5)
        return a;
    if (role > 1.5)
        return d;
    return qt_MultiTexCoord0.x < 0.5 ? b : c;
}

vec2 square(float role, vec2 m, float h) {
    return corner(role, m - h, m + vec2(-h, h), m + vec2(h, -h), m + h);
}

// Snowflake j of a layer (0 far, 1 middle, 2 near): its center, radius, and spin,
// and its opacity.
vec4 flake(float j, float layer, out float alpha) {
    vec4 rnd = vec4(hash(vec2(j, 11.3 + layer)), hash(vec2(j, 12.7 + layer)), hash(vec2(j, 13.9 + layer)), hash(vec2(j, 15.1 + layer)));
    vec2 lo = u.rect.xy - vec2(170.0, 190.0);
    vec2 area = u.rect.zw + vec2(340.0, 340.0);
    float speed = (layer < 0.5 ? 15.0 : layer < 1.5 ? 26.0 : 44.0) * mix(0.8, 1.25, rnd.x);
    float y = mod(rnd.y * area.y + speed * u.time, area.y);
    // A breeze that comes and goes, stronger on the near flakes, and each flake's sway.
    float wind = (0.5 + 0.5 * layer) * (4.0 * u.time + 26.0 * sin(0.15 * u.time + 1.0));
    float sway = mix(2.0, 6.0 + 3.0 * layer, rnd.z) * sin(u.time * mix(0.5, 1.2, rnd.w) + TAU * rnd.x);
    float x = mod(rnd.z * area.x + wind + sway, area.x);
    vec2 c = lo + vec2(x, y);
    float d = sdRoundRect(c - center(), halfSize(), rad());
    float appear = 0.35 + 2.2 * hash(vec2(j, 17.3 + layer));
    alpha = (1.0 - smoothstep(60.0, 155.0, d)) * smoothstep(appear, appear + 0.7, u.open) * (1.0 - smoothstep(0.0, 0.4, u.leave))
          * (layer < 0.5 ? 0.42 : layer < 1.5 ? 0.7 : 0.92);
    float size = layer < 0.5 ? mix(0.8, 1.35, rnd.w) : layer < 1.5 ? mix(1.3, 2.1, rnd.w) : mix(2.8, 4.0, rnd.w);
    return vec4(c, size, rnd.y * TAU + u.time * (rnd.x - 0.5) * 0.9);
}

void main() {
    float row = floor(qt_MultiTexCoord0.y * float(ROWS - 1) + 0.5);
    float front = laid();
    p = vec2(-64.0);
    piece = vec4(0.0);
    shape = vec4(0.0);
    look = vec4(-1.0, 0.0, 0.0, 0.0);
    float back = float(3 * (FAR + MID));
    float wireEnd = back + float(WIRE);

    if (row < back) {
        // Far and middle snow.
        float slot = floor(row / 3.0), role = row - 3.0 * slot;
        float layer = slot < float(FAR) ? 0.0 : 1.0;
        float alpha;
        vec4 f = flake(layer < 0.5 ? slot : slot - float(FAR), layer, alpha);
        if (alpha > 0.0) {
            p = square(role, f.xy, f.z + 1.5);
            piece = f;
            look = vec4(0.0, alpha, layer, 0.0);
        }
    } else if (row < wireEnd) {
        // The wire, a ribbon along it up to its free end.
        float rr = row - back;
        if (front > 0.5) {
            float sg = min(clamp((rr - 1.0) / float(WIRE - 3), 0.0, 1.0) * perim(), front);
            vec2 w = wireAt(sg, front);
            vec2 t = normalize(wireAt(sg + 0.6, front) - wireAt(sg - 0.6, front) + 1e-6);
            bool cap = rr < 0.5 || rr > float(WIRE) - 1.5;
            float side = cap ? 0.0 : qt_MultiTexCoord0.x * 2.0 - 1.0;
            p = w + vec2(-t.y, t.x) * side * HW;
            piece = vec4(sg, 0.0, 0.0, 0.0);
            shape = vec4(side, 0.0, 0.0, 0.0);
            look = vec4(1.0, 1.0 - smoothstep(0.1, 0.26, fallAt(sg).y), 0.0, 0.0);
        }
    } else {
        float rr = row - wireEnd;
        float slot = floor(rr / 3.0), role = rr - 3.0 * slot;
        vec2 b, dir;
        vec4 state;
        if (slot < float(BULBS)) {
            if (bulb(slot, front, b, dir, state)) {
                vec2 n = vec2(-dir.y, dir.x) * 3.6 * state.x;
                vec2 tip = b + dir * (BULB + 1.0) * state.x;
                vec2 root = b - dir;
                p = corner(role, root - n, root + n, tip - n, tip + n);
                piece = vec4(b, dir);
                shape = state;
                look = vec4(2.0, 0.0, 0.0, 0.0);
            }
        } else if (slot < float(BULBS + 1)) {
            // The drift's band along the top edge.
            if (u.open > 0.8 && u.leave < 0.45) {
                vec2 a = u.rect.xy + vec2(-4.0, -30.0), d = u.rect.xy + vec2(u.rect.z + 4.0, 7.0);
                p = corner(role, a, vec2(a.x, d.y), vec2(d.x, a.y), d);
                look = vec4(3.0, 0.0, 0.0, 0.0);
            }
        } else if (slot < float(2 * BULBS + 1)) {
            // A bulb's glow, round its glass.
            if (bulb(slot - float(BULBS + 1), front, b, dir, state) && state.y > 0.01) {
                vec2 g = b + dir * GLASS * state.x;
                float R = 21.0 * state.x;
                p = square(role, g, R);
                piece = vec4(g, R, 0.0);
                shape = state;
                look = vec4(4.0, 0.0, 0.0, 0.0);
            }
        } else if (slot < float(2 * BULBS + 1 + PUFFS)) {
            // Puffs of the drift, thrown up as it is wrapped.
            float j = slot - float(2 * BULBS + 1);
            float tau = u.leave * u.exitTime - 0.06 * hash(vec2(j, 1.1));
            float life = mix(0.28, 0.42, hash(vec2(j, 7.7)));
            float grown = smoothstep(1.0, 8.0, u.open);
            if (tau > 0.0 && tau < life && grown > 0.05) {
                vec2 h = halfSize();
                float x = mix(-1.0, 1.0, hash(vec2(j, 2.2))) * (h.x - rad());
                vec2 start = vec2(center().x + x, u.rect.y - 2.0 - 7.0 * grown * hash(vec2(j, 3.3)));
                vec2 v = vec2(sign(x) * mix(20.0, 110.0, hash(vec2(j, 4.4))) + (hash(vec2(j, 8.8)) - 0.5) * 70.0,
                              -mix(70.0, 200.0, hash(vec2(j, 5.5))));
                vec2 c = start + v * (1.0 - exp(-5.0 * tau)) / 5.0 + vec2(0.0, 140.0 * tau * tau);
                float s = mix(1.5, 3.6, hash(vec2(j, 6.6))) * (1.0 + 1.4 * tau / life) * mix(0.6, 1.0, grown);
                p = square(role, c, s + 1.5);
                piece = vec4(c, s, 0.0);
                look = vec4(5.0, pow(1.0 - tau / life, 1.5) * grown, 0.0, 0.0);
            }
        } else {
            // Near snow, in front of everything.
            float alpha;
            vec4 f = flake(slot - float(2 * BULBS + 1 + PUFFS), 2.0, alpha);
            if (alpha > 0.0) {
                p = square(role, f.xy, f.z + 1.5);
                piece = f;
                look = vec4(0.0, alpha, 2.0, 0.0);
            }
        }
    }
    gl_Position = u.qt_Matrix * vec4(p - u.origin, 0.0, qt_Vertex.w);
}
