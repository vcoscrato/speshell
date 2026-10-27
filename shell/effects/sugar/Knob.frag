#version 440
#extension GL_GOOGLE_include_directive : enable
// Sugar's knob: frosting piped along the track. From the track's start to the knob
// lies a border of shells, each swelling from a point to a round head, ribbed by the
// star nozzle, a sugar pearl set on every few, fixed to the track so new ones are
// piped as the knob moves out. It ends at the knob in a kiss, the dome piping leaves
// when the bag lifts off, its peak drawn up and curling back. As the pointer nears,
// the piping bag comes down onto the kiss, leaning back over the border; held, it is
// squeezed. Going back, an offset spatula takes its place, scraping the frosting off
// with a heap of it on its blade. Switched off, the track is bare and the kiss is
// plain meringue.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;          // the item's size, px
    vec2 center;        // px, the knob's center in the item
    float size;         // the knob's diameter, px
    float back;         // px from the knob's center back to the track's start
    float lag;          // -1..1 how far a springy copy of the knob trails it, + to the right
    float squeeze;      // 0..1 held
    float fill;         // 0..1 switched on
    float near;         // 0..1 the pointer near, which brings a tool down
    float scrape;       // 0 the bag, 1 the spatula
    vec4 cFrost;
    vec4 cFrostLight;
    vec4 cFrostShade;
    vec4 cFilm;
    vec4 cMetal;
    vec4 cMetalShade;
    vec4 cMeringue;
    vec4 cHandle;
} u;
#include "../common/common.glsl"
#include "Bag.glsl"

const float PI = 3.1415927;

// Frosting shaded as a round thing lit from the upper left: `v` runs -1 (lit) to 1
// across it.
vec3 frostTone(vec3 base, vec3 lite, vec3 shade, float v) {
    vec3 c = mix(base, shade, band(v, 0.3));
    c = mix(c, lite, band(-v, 0.4));
    return mix(c, shade * 0.8, band(v, 0.8) * 0.6);
}

// A pearl of sugar of radius r at c: shaded round, with a glint.
vec4 pearl(vec4 o, vec2 p, vec2 c, float r) {
    vec2 d = (p - c) / r;
    float l = length(d);
    vec3 pc = mix(u.cFilm.rgb, u.cMetalShade.rgb, 0.15 + 0.45 * band(dot(d, normalize(vec2(0.5, 0.8))), 0.2));
    pc = mix(pc, u.cFilm.rgb, cover((0.32 - length(d + vec2(0.35, 0.35))) * r));
    return over(o, pc, cover((1.0 - l) * r));
}

void main() {
    vec2 p = qt_TexCoord0 * u.area - u.center;
    float k = u.size;
    float xs = p.x + u.back;                     // px from the track's start
    vec4 o = vec4(0.0);
    float aa = 0.8;

    // ── The piped border, from the track's start to the kiss ──
    float H = k * 0.3;
    if (u.fill > 0.01 && xs > -H && p.x < k * 0.2 && abs(p.y) < H * 1.4) {
        float P = max(6.0, k * 0.5);
        float i = floor(xs / P);
        float f = fract(xs / P);
        float w = H * (0.3 + 0.7 * sin(PI * pow(f, 0.62))) * u.fill;
        float d = max(max(abs(p.y) - w, -xs), p.x);
        float v = p.y / max(w, 0.5);
        vec3 c = frostTone(u.cFrost.rgb, u.cFrostLight.rgb, u.cFrostShade.rgb, v);
        // The ridges the star nozzle leaves, swirling round each shell.
        float rib = fract(f * 2.0 - v * 0.35 + 0.15);
        c = mix(c, u.cFrostShade.rgb, 0.45 * band(rib, 0.7) * (1.0 - band(rib, 0.9)));
        o = over(o, u.cFrostShade.rgb * 0.75, cover(aa - d) * 0.8);
        o = over(o, c, cover(-d));
        if (mod(i, 3.0) < 0.5 && (i + 1.0) * P < u.back - k * 0.3)
            o = pearl(o, p, vec2((i + 0.55) * P - u.back, -w * 0.15), max(1.2, k * 0.1) * u.fill);
    }

    // ── The kiss at the knob: a dome drawn up into a curling peak ──
    {
        float R = k * 0.42 * mix(1.0, 0.7, u.scrape * u.near) * mix(0.85, 1.0, u.fill) * (1.0 + 0.1 * u.squeeze);
        vec2 dc = vec2(0.0, R * 0.05);
        float dd = length((p - dc) / vec2(1.0, 0.86)) * 0.93 - R;
        dd = max(dd, p.y - R * 0.55);
        // The peak, tapering as it rises and curling back.
        vec2 a = dc + vec2(0.0, -R * 0.4), b = dc + vec2(-R * 0.45, -R * 1.55);
        vec2 pa = p - a, ba = b - a;
        float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
        vec2 bend = vec2(-R * 0.25 * h * h, 0.0);
        float dp = length(pa - ba * h - bend) - mix(R * 0.55, R * 0.06, pow(h, 0.8));
        float d = min(dd, dp);
        // Smooth where the peak rises from the dome.
        float hk = R * 0.3;
        float m = clamp(0.5 + 0.5 * (dp - dd) / hk, 0.0, 1.0);
        d = mix(dp, dd, m) - hk * m * (1.0 - m);
        if (d < aa + 1.0) {
            vec2 n = (p - dc - vec2(-R * 0.1, -R * 0.35)) / (R * 1.2);
            float v = clamp(dot(n, normalize(vec2(0.45, 0.9))) * 1.4, -1.0, 1.0);
            vec3 base = mix(u.cMeringue.rgb, u.cFrost.rgb, u.fill);
            vec3 lite = mix(u.cFilm.rgb, u.cFrostLight.rgb, u.fill);
            vec3 shade = mix(mix(u.cMeringue.rgb, u.cMetalShade.rgb, 0.45), u.cFrostShade.rgb, u.fill);
            vec3 c = frostTone(base, lite, shade, v);
            // The star nozzle's ridges, running up into the peak.
            vec2 tq = p - (b + bend);
            float rib = fract(atan(tq.x, tq.y) / PI * 3.5 + 0.5);
            c = mix(c, shade, 0.5 * band(rib, 0.72) * (1.0 - band(rib, 0.9)) * smoothstep(R * 0.2, R * 0.6, length(tq)));
            o = over(o, shade * 0.75, cover(aa - d) * 0.8);
            o = over(o, c, cover(-d));
        }
    }

    // ── The bag, come down onto the kiss, leaning back over the border ──
    float bagOn = u.near * (1.0 - u.scrape);
    if (bagOn > 0.01) {
        float K = k * 1.75;
        float R = k * 0.42;
        vec2 tip = vec2(-R * 0.4, -R * 1.45 - (1.0 - bagOn) * k * 0.8 + k * 0.06 * u.squeeze);
        float ang = -2.2 + 0.12 * u.lag;
        vec2 ax = vec2(cos(ang), sin(ang));
        vec2 q = p - tip;
        // Across it, its -y side toward the light from the upper left.
        vec2 b = vec2(dot(q, ax), dot(q, vec2(ax.y, -ax.x)));
        vec4 bag = pipingBag(b, K, 0.72 - 0.15 * u.squeeze, u.squeeze);
        o = bag * bagOn + o * (1.0 - bag.a * bagOn);
    }

    // ── The offset spatula, scraping back, its blade's tip on the track ──
    float spatOn = u.near * u.scrape;
    if (spatOn > 0.01) {
        vec2 tip = vec2(k * 0.2, k * 0.2 - (1.0 - spatOn) * k * 0.8);
        float ang = -0.95 - 0.08 * u.lag;
        vec2 ax = vec2(cos(ang), sin(ang));
        vec2 q = p - tip;
        vec2 b = vec2(dot(q, ax), dot(q, vec2(ax.y, -ax.x)));
        float bw = k * 0.3;
        // The blade, round-ended; the neck, bent up out of it; the handle.
        float blade = sdSeg(b, vec2(bw, 0.0), vec2(k * 1.35, 0.0)) - bw;
        float neck = sdSeg(b, vec2(k * 1.4, 0.0), vec2(k * 1.7, -k * 0.22)) - k * 0.07;
        float handle = sdSeg(b, vec2(k * 1.75, -k * 0.22), vec2(k * 2.6, -k * 0.22)) - k * 0.16;
        vec4 s = vec4(0.0);
        if (min(min(blade, neck), handle) < aa + 1.0) {
            float vb = clamp(b.y / bw, -1.0, 1.0);
            vec3 mc = mix(u.cMetal.rgb, u.cMetalShade.rgb, band(vb, 0.3) * 0.55);
            mc = mix(mc, u.cFilm.rgb, cover(max(0.6, k * 0.04) - abs(vb + 0.55) * bw) * 0.9);
            s = over(s, u.cMetalShade.rgb, cover(aa - blade) * 0.8);
            s = over(s, mc, cover(-blade));
            s = over(s, mix(u.cMetal.rgb, u.cMetalShade.rgb, 0.4), cover(-neck));
            float vh = clamp((b.y + k * 0.22) / (k * 0.16), -1.0, 1.0);
            vec3 hc = mix(u.cHandle.rgb, u.cHandle.rgb * 0.62, band(vh, 0.3));
            hc = mix(hc, mix(u.cHandle.rgb, u.cFilm.rgb, 0.35), band(-vh, 0.55));
            hc = mix(hc, u.cMetal.rgb, cover(k * 0.06 - length(b - vec2(k * 2.05, -k * 0.22))));
            hc = mix(hc, u.cMetal.rgb, cover(k * 0.06 - length(b - vec2(k * 2.35, -k * 0.22))));
            s = over(s, u.cHandle.rgb * 0.5, cover(aa - handle) * 0.8);
            s = over(s, hc, cover(-handle));
            // The frosting scraped up onto the blade's face, heaped at its tip.
            vec2 hq = b - vec2(k * 0.42, bw * 0.1);
            float hp = length(hq / vec2(1.3, 0.85)) - k * 0.3 - k * 0.04 * sin(atan(hq.y, hq.x) * 5.0);
            vec3 fc = frostTone(u.cFrost.rgb, u.cFrostLight.rgb, u.cFrostShade.rgb, clamp(hq.y / (k * 0.3), -1.0, 1.0));
            s = over(s, u.cFrostShade.rgb * 0.75, cover(aa - hp) * cover(-blade + 0.5) * 0.8);
            s = over(s, fc, cover(-hp) * cover(-blade + 0.5));
        }
        o = s * spatOn + o * (1.0 - s.a * spatOn);
    }

    fragColor = o * u.qt_Opacity;
}
