#version 440
#extension GL_GOOGLE_include_directive : enable
// Natal's knob: a glass bauble, cel-shaded round under one light, a crimped metal
// cap on its neck and a gilt band round its middle set with garnets, all rolling
// with its travel while the light and the window's sheen stay put. On a slider, the
// filled track behind it is a dark ribbon strung with fairy lights: a green wire from
// a plug at the track's start, sagging between bulbs that hang this way and that,
// each lit in turn in the string's colors and pooling its light on the ribbon. The
// bulbs are fixed to the track, so the knob uncovers them as it goes. On a switch,
// the whole switch: a dark capsule with a short string, dark when off, coming on
// bulb by bulb when switched on, the bauble rolling along it.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;          // the item's size, px
    vec2 center;        // px, the bauble's center in the item
    vec4 body;          // px, the switch in the item (x, y, w, h); w is 0 on a slider
    float size;         // the knob's diameter, px
    float unit;         // its diameter at rest, px: the lights' scale
    float back;         // px from the bauble's center back to the track's start
    float turn;         // radians it has rolled, clockwise
    float warm;         // 0..1 held
    float lit;          // 0..1 the lights on
    float kindle;       // 0..1 since they were switched on
    vec4 cBall;
    vec4 cBallLight;
    vec4 cBallShade;
    vec4 cBallDeep;
    vec4 cBand;
    vec4 cBandShade;
    vec4 cCap;
    vec4 cCapLight;
    vec4 cSheen;
    vec4 cGlow;
    vec4 cNight;
    vec4 cRim;
    vec4 cWire;
    vec4 cBulb0;
    vec4 cBulb1;
    vec4 cBulb2;
    vec4 cBulb3;
    vec4 cBulb4;
} u;
#include "../common/common.glsl"

const vec3 LIGHT = vec3(-0.55, -0.68, 0.48);    // toward the light: up, left, and out
const float TILT = 0.38;                         // the cap leans toward us by this, rad

vec3 bulbColor(float i) {
    float k = mod(i, 5.0);
    return k < 0.5 ? u.cBulb0.rgb : k < 1.5 ? u.cBulb1.rgb : k < 2.5 ? u.cBulb2.rgb : k < 3.5 ? u.cBulb3.rgb : u.cBulb4.rgb;
}

// One bulb of the string: (x, y) its socket on the wire, a the way it points (radians
// from straight down, clockwise), l its length.
struct Bulb { vec2 at; float a; float l; };

// Bulb i of a slider's string, x from the track's start; i -1 is the plug.
Bulb sliderBulb(float i) {
    float P = u.unit * 0.64;
    if (i < 0.0)
        return Bulb(vec2(u.unit * 0.24, -u.unit * 0.04), 0.0, 0.0);
    float h = hash(vec2(i, 7.1));
    float x = (i + 0.75 + 0.5 * (hash(vec2(i, 3.3)) - 0.5)) * P;
    float y = -u.unit * 0.07 + (hash(vec2(i, 5.9)) - 0.5) * u.unit * 0.06;
    // Most hang, leaning either way; now and then one stands up off the wire.
    float a = (hash(vec2(i, 1.7)) - 0.5) * 1.7 + (h < 0.24 ? PI : 0.0);
    return Bulb(vec2(x, y), a, u.unit * 0.33 * mix(0.9, 1.1, hash(vec2(i, 9.4))));
}

// Bulb i of a switch's four, from its top-left; -1 and 4 are its two ends.
Bulb switchBulb(float i, vec2 wh) {
    float H = wh.y;
    if (i < 0.0 || i > 3.5)
        return Bulb(vec2(i < 0.0 ? H * 0.27 : wh.x - H * 0.27, H * 0.46), 0.0, 0.0);
    float x = wh.x * (0.25 + 0.168 * i) + (hash(vec2(i, 3.3)) - 0.5) * H * 0.06;
    float a = i == 0.0 ? 0.35 : i == 1.0 ? PI + 0.4 : i == 2.0 ? -0.3 : PI - 0.35;
    return Bulb(vec2(x, H * 0.47), a, H * 0.34);
}

// The wire between two sockets, sagging: (distance, height) at x.
float wireDist(vec2 p, vec2 a, vec2 b, float sag) {
    if (p.x < a.x - 0.5 || p.x > b.x + 0.5)
        return 1e3;
    float f = clamp((p.x - a.x) / max(b.x - a.x, 1e-3), 0.0, 1.0);
    float y = mix(a.y, b.y, f) + sag * 4.0 * f * (1.0 - f);
    float slope = (b.y - a.y + sag * 4.0 * (1.0 - 2.0 * f)) / max(b.x - a.x, 1e-3);
    return abs(p.y - y) / sqrt(1.0 + slope * slope);
}

// The light a lit bulb pools round itself, in two flat steps; inside says how much
// falls on the ribbon rather than past it.
vec4 pool(vec4 o, vec2 p, Bulb b, vec3 col, float on, float inside) {
    vec2 dir = vec2(-sin(b.a), cos(b.a));
    float r = length(p - b.at - dir * b.l * 0.6);
    float k = on * mix(0.3, 1.0, inside) * (1.0 + 0.35 * u.warm);
    o = over(o, col, cover(b.l * 1.15 - r) * 0.14 * k);
    return over(o, col, cover(b.l * 0.72 - r) * 0.18 * k);
}

// A bulb: a socket of the wire's green, and a glass drop, lit (on 1) or dark.
vec4 bulb(vec4 o, vec2 p, Bulb b, vec3 col, float on, float fat) {
    vec2 d = p - b.at;
    vec2 dir = vec2(-sin(b.a), cos(b.a));
    float along = dot(d, dir), across = dot(d, vec2(dir.y, -dir.x));
    float l = b.l;
    float sock = sdRoundRect(vec2(across, along - l * 0.15), vec2(l * 0.13, l * 0.15) * (1.0 - 0.3 * fat), l * 0.05);
    // A drop, round at the socket and drawn to a soft point.
    float t = clamp((along - l * 0.62) / (l * 0.4), -1.0, 1.0);
    float w = l * mix(0.3, 0.38, fat) * (1.0 - 0.38 * max(t, 0.0) * max(t, 0.0));
    float e = length(vec2(across / w, (along - l * 0.62) / (l * 0.4)));
    float g = (e - 1.0) * w;
    vec3 dark = mix(col, u.cNight.rgb, 0.72);
    vec3 glass = mix(dark, mix(col, u.cSheen.rgb, 0.15), on);
    glass = mix(glass, mix(col, u.cSheen.rgb, 0.65), on * band(-e, -0.5));
    // The glint, on the side toward the light.
    vec2 gl = vec2(across + w * 0.35, along - l * 0.5);
    glass = mix(glass, mix(u.cSheen.rgb, dark, 0.5 * (1.0 - on)), cover(l * 0.07 + 0.25 - length(gl)) * 0.85);
    o = over(o, mix(u.cWire.rgb, u.cNight.rgb, 0.25), cover(-sock));
    return over(o, glass, cover(-g));
}

// Whether bulb i of a switch has come on yet, as they flicker on one by one.
float kindled(float i) {
    float t = u.kindle - (0.04 + 0.46 * hash(vec2(i, 2.2)));
    return t < 0.0 ? 0.0 : t < 0.07 ? 1.0 : t < 0.15 ? 0.25 : 1.0;
}

// The bauble, centered at the origin.
vec4 bauble(vec4 o, vec2 p) {
    float R = u.size * 0.41;
    float r = length(p);
    // Held, it warms, and its glow spreads round it in two flat steps.
    if (u.warm > 0.0) {
        o = over(o, u.cGlow.rgb, cover(R * 1.8 - r) * 0.1 * u.warm);
        o = over(o, u.cGlow.rgb, cover(R * 1.42 - r) * 0.16 * u.warm);
    }
    vec2 q = rot(p, -u.turn);                   // on the turning ball
    vec3 L = normalize(LIGHT);

    // ── The glass ──
    float d = r - R;
    if (d < 1.5) {
        vec3 n = vec3(p / R, sqrt(max(0.0, 1.0 - r * r / (R * R))));
        float dif = dot(n, L);
        vec3 c = u.cBall.rgb;
        c = mix(c, u.cBallShade.rgb, band(-dif, 0.12));
        c = mix(c, u.cBallDeep.rgb, band(-dif, 0.5));
        c = mix(c, u.cBallLight.rgb, band(dif, 0.72));
        // The room's light thrown back off its far edge.
        float bounce = band(r / R, 0.8) * band(dot(p / max(r, 1e-3), vec2(0.62, 0.78)), 0.6);
        c = mix(c, u.cBallShade.rgb, bounce * 0.8);
        // The band round its middle, on the ball's own sphere, which leans toward us.
        vec3 nb = vec3(rot(n.xy, -u.turn), n.z);
        float lat = dot(nb, vec3(0.0, -cos(TILT), sin(TILT)));
        float lon = atan(nb.x, dot(nb, vec3(0.0, sin(TILT), cos(TILT))));
        float bw = 0.19;
        vec3 bc = mix(u.cBand.rgb, u.cBandShade.rgb, band(-dif, 0.12));
        bc = mix(bc, mix(u.cBand.rgb, u.cSheen.rgb, 0.45), band(dif, 0.72));
        // Garnets set along it, smaller toward its rims.
        float cell = abs(fract(lon / (TAU / 11.0)) - 0.5) * 2.0;
        float gem = cover((0.55 - cell - abs(lat) / bw * 0.7) * R * 0.28);
        bc = mix(bc, mix(u.cBallDeep.rgb, u.cBall.rgb, band(dif, 0.12) * 0.6), gem);
        float faceOn = smoothstep(0.0, 0.25, n.z);
        c = mix(c, bc, cover((bw - abs(lat)) * R) * faceOn);
        // A thin gilt line either side of it.
        c = mix(c, bc, cover((0.035 - abs(abs(lat) - bw - 0.09)) * R) * faceOn);
        // The window's sheen, and a smaller one under it.
        vec3 Hv = normalize(L + vec3(0.0, 0.0, 1.0));
        float sp = dot(n, Hv);
        c = mix(c, u.cSheen.rgb, band(sp, 0.968));
        c = mix(c, mix(c, u.cSheen.rgb, 0.7), cover(R * 0.075 - length(p - R * vec2(-0.12, -0.12))));
        c = mix(c, u.cGlow.rgb, 0.2 * u.warm * (1.0 - band(-dif, 0.12)));
        o = over(o, c, cover(-d));
    }

    // ── The cap, crimped round the neck, and the wire loop it hangs by ──
    float capD = sdRoundRect(q - vec2(0.0, -R * 1.0), vec2(R * 0.26 + min(0.0, q.y + R) * 0.08, R * 0.19), R * 0.07);
    float loopD = abs(length(q - vec2(0.0, -R * 1.3)) - R * 0.12) - max(0.35, R * 0.04);
    if (min(capD, loopD) < 1.5) {
        // Lit by the fixed light, in the cap's own frame.
        vec2 lq = rot(vec2(L.x, L.y), -u.turn);
        float side = q.x / (R * 0.26) * sign(-lq.x + 1e-4);
        vec3 cc = mix(u.cCap.rgb, u.cCapLight.rgb, band(side, 0.15) * smoothstep(-0.6, 0.2, -lq.y + abs(lq.x)));
        cc = mix(cc, mix(u.cCap.rgb, u.cBallDeep.rgb, 0.5), band(-side, 0.55));
        float crimp = abs(fract((q.y + R * 1.19) / (R * 0.19)) - 0.5);
        cc = mix(cc, mix(u.cCap.rgb, u.cBallDeep.rgb, 0.45), cover((0.12 - crimp) * R * 0.19) * step(q.y, -R * 0.85));
        o = over(o, mix(u.cCap.rgb, u.cBallDeep.rgb, 0.4), cover(-loopD) * smoothstep(5.0, 9.0, R));
        o = over(o, cc, cover(-capD));
    }
    return o;
}

void main() {
    vec2 px = qt_TexCoord0 * u.area;
    vec2 p = px - u.center;
    vec4 o = vec4(0.0);

    if (u.body.z <= 0.0) {
        // ── A slider: the ribbon of lights from the track's start ──
        float xs = p.x + u.back;                // px from the track's start
        float hb = u.unit * 0.25;
        vec2 rq = vec2(p.x + u.back * 0.5, p.y);
        float rib = sdRoundRect(rq, vec2(u.back * 0.5 + 0.5, hb), hb);
        if (xs > -u.unit * 0.6 && p.x < 0.0 && abs(p.y) < u.unit * 0.9) {
            o = over(o, u.cNight.rgb, cover(-rib));
            float inside = cover(-rib);
            float P = u.unit * 0.64;
            float i0 = floor(xs / P);
            // The light each bulb pools, then the wire, then the bulbs over it.
            for (int j = -2; j <= 2; j++) {
                float i = i0 + float(j);
                if (i < 0.0)
                    continue;
                Bulb b = sliderBulb(i);
                if (b.at.x < u.back)
                    o = pool(o, p + vec2(u.back, 0.0), b, bulbColor(i), u.lit, inside);
            }
            vec2 ps = vec2(xs, p.y);
            float wd = 1e3;
            for (int j = -2; j <= 1; j++) {
                float i = i0 + float(j);
                if (i < -1.0)
                    continue;
                Bulb a = sliderBulb(i), b = sliderBulb(i + 1.0);
                if (xs >= a.at.x - 0.5 && xs <= b.at.x + 0.5)
                    wd = min(wd, wireDist(ps, a.at, b.at, u.unit * mix(0.06, 0.11, hash(vec2(i, 4.4)))));
            }
            float ww = max(0.45, u.unit * 0.04);
            o = over(o, u.cWire.rgb, cover(ww - wd) * step(u.unit * 0.24, xs));
            // The plug the string starts from.
            float plug = sdRoundRect(ps - vec2(u.unit * 0.2, -u.unit * 0.04), vec2(u.unit * 0.09, u.unit * 0.1), u.unit * 0.04);
            o = over(o, mix(u.cWire.rgb, u.cNight.rgb, 0.3), cover(-plug));
            for (int j = -1; j <= 1; j++) {
                float i = i0 + float(j);
                if (i < 0.0)
                    continue;
                Bulb b = sliderBulb(i);
                if (b.at.x < u.back)
                    o = bulb(o, ps, b, bulbColor(i), u.lit, 0.0);
            }
        }
    } else {
        // ── A switch: a dark capsule strung with four bulbs ──
        vec2 wh = u.body.zw;
        vec2 s = px - u.body.xy;
        float H = wh.y;
        float cap = sdRoundRect(s - wh * 0.5, wh * 0.5 + 0.5, H * 0.5 + 0.5);
        o = over(o, u.cRim.rgb, cover(-cap));
        o = over(o, u.cNight.rgb, cover(-cap - max(0.8, H * 0.05)));
        float inside = cover(-cap - 1.0);
        for (int j = 0; j < 4; j++) {
            float i = float(j);
            o = pool(o, s, switchBulb(i, wh), bulbColor(i + 1.0), u.lit * kindled(i) * 1.4, inside);
        }
        float wd = 1e3;
        for (int j = -1; j < 4; j++) {
            float i = float(j);
            wd = min(wd, wireDist(s, switchBulb(i, wh).at, switchBulb(i + 1.0, wh).at, H * (0.05 + 0.03 * mod(i + 2.0, 2.0))));
        }
        o = over(o, u.cWire.rgb, cover(max(0.45, H * 0.035) - wd));
        // A knot at either end, where it goes through.
        for (int j = 0; j < 2; j++)
            o = over(o, mix(u.cWire.rgb, u.cNight.rgb, 0.3), cover(H * 0.07 + 0.3 - length(s - switchBulb(float(j) * 5.0 - 1.0, wh).at)));
        for (int j = 0; j < 4; j++) {
            float i = float(j);
            o = bulb(o, s, switchBulb(i, wh), bulbColor(i + 1.0), u.lit * kindled(i), 1.0);
        }
    }

    o = bauble(o, p);
    fragColor = o * u.qt_Opacity;
}
