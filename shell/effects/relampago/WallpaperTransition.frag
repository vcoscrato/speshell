#version 440
#extension GL_GOOGLE_include_directive : enable
// The old wallpaper split by lightning, like a cartoon. A fat bolt, outlined in
// rubber and banded from a white-hot core through yellow to orange, strikes down the
// screen in jagged zigzags, forking; for an instant the picture turns to a two-tone
// impact frame, then flashes and shakes, and a comic starburst bursts where it lands.
// The image tears apart along the bolt's path, arcs of electricity snapping across the
// widening gap, and the two halves are flung off to either side, tipping outward
// about their bottom corners, crisp: their torn edges inked, scorched, and glowing
// hot and cooling, speed lines streaming off them and sparks spilling into the gap
// where the new wallpaper shows.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    float progress;     // 0..1
    float seed;         // 0..1, a new bolt each time
    vec4 cCore;
    vec4 cGlow;
    vec4 cEdge;
    vec4 cPaint;
    vec4 cRubber;
    float columns;      // the bolt table's width
    float bands;        // the embers table's width
} u;
layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D tear;     // WallpaperTransition.tear.frag
layout(binding = 3) uniform sampler2D embers;   // WallpaperTransition.embers.frag
#include "../common/common.glsl"
#include "Star.glsl"
#include "Tear.glsl"

const float STRIKE = 0.08;      // the bolt reaching the bottom
const float IMPACT = 0.06;      // how long the impact frame holds after it
const float SPLIT = 0.16;       // the halves starting to move

// Where the bolt crosses height y (px), from its table: exact at each row's middle,
// and straight between them.
float tearX(float y) {
    float i = floor(y - 0.5);
    float a = texture(tear, vec2((i + 0.5) / u.columns, 0.25)).x;
    float b = texture(tear, vec2((i + 1.5) / u.columns, 0.25)).x;
    return mix(a, b, y - 0.5 - i);
}

// Texel i of the table's second row.
vec4 traits(float i) {
    return texture(tear, vec2((i + 0.5) / u.columns, 0.75));
}

float span(float x, float a, float b) { return clamp((x - a) / (b - a), 0.0, 1.0); }

void main() {
    vec2 p = qt_TexCoord0 * u.resolution;
    float t = u.progress;
    float W = u.resolution.x, H = u.resolution.y;
    float s = span(t, SPLIT, 1.0);
    float gap = W * 0.72 * pow(s, 2.1);
    float tilt = 0.12 * pow(s, 1.6);
    float heat = 1.0 - span(t, 0.3, 0.95);
    // The jolt of the strike, dying away as the halves start to move.
    float jolt = exp(-max(t - STRIKE, 0.0) * 28.0) * step(STRIKE, t);
    vec2 shake = 9.0 * jolt * vec2(sin(t * 260.0), cos(t * 190.0 + 1.0));
    float tx = tearX(p.y);

    vec4 col = vec4(0.0);
    // ── Arcs of electricity snapping across the gap as it opens, under the halves,
    //    which cover their ends ──
    if (s > 0.0 && s < 0.4) {
        float flick = floor(t * 1.15 * 22.0);
        for (int i = 0; i < 3; i++) {
            float fi = float(i);
            float y0 = H * (0.18 + 0.3 * fi + 0.12 * hash(vec2(fi, u.seed * 31.0)));
            if (abs(p.y - y0) > 46.0 || abs(p.x - tx) > gap + 60.0)
                continue;
            float x = p.x - tx;
            float f = clamp(x / (gap + 60.0) * 0.5 + 0.5, 0.0, 1.0);
            #define ARC(x) (y0 - 18.0 * sin(PI * f) + 26.0 * zig((x) / 31.0, flick + fi * 7.0) * sin(PI * f) \
                + 7.0 * zig((x) / 9.0, flick + fi * 7.0 + 3.0))
            float ay = ARC(x);
            float ay2 = ARC(x + 1.0);
            #undef ARC
            float d = abs(p.y - ay) / sqrt(1.0 + (ay2 - ay) * (ay2 - ay));
            float on = step(0.25, hash(vec2(flick, fi + 5.0))) * (1.0 - smoothstep(0.25, 0.4, s));
            float w = 1.6 * (1.0 - s * 2.0);
            col = over(col, u.cRubber.rgb, cover(w + 2.5 - d) * on);
            col = over(col, u.cGlow.rgb, cover(w + 1.2 - d) * on);
            col = over(col, u.cCore.rgb, cover(w - d) * on);
        }
    }

    // ── Each half, flung out and tipping about its bottom outer corner, sampled
    //    crisp: inked along its torn edge, scorched inside the ink, and inside that a
    //    band of heat that narrows and cools from white-hot to red ──
    for (int side = 0; side < 2; side++) {
        float dir = side == 0 ? -1.0 : 1.0;
        vec2 pivot = vec2(side == 0 ? 0.0 : W, H);
        vec2 src = pivot + rot(p - vec2(dir * gap, 0.0) - shake - pivot, -dir * tilt);
        float ex = tearX(src.y);
        float slope = tearX(src.y + 1.0) - ex;
        float own = (side == 0 ? ex - src.x : src.x - ex) / sqrt(1.0 + slope * slope);  // px inside, < 0 past its edge
        if (own > -2.0) {
            vec2 uv = clamp(src / u.resolution, vec2(0.0), vec2(1.0));
            vec4 half_ = texture(source, uv) * cover(own);
            if (s > 0.0) {
                float ink = 2.5 * smoothstep(0.0, 0.05, s);
                float soot = 1.0 - smoothstep(0.0, 12.0 + 22.0 * vnoise(vec2(src.y / 23.0, float(side) * 9.0)), own - ink);
                half_.rgb = mix(half_.rgb, u.cRubber.rgb * half_.a, soot * 0.55 * smoothstep(0.0, 0.08, s));
                float hw = ink + 10.0 * heat;
                vec3 hot = mix(u.cPaint.rgb, u.cEdge.rgb, band(heat, 0.35));
                hot = mix(hot, u.cGlow.rgb, band(heat, 0.6) * (1.0 - band(own, ink + 4.5 * heat)));
                hot = mix(hot, u.cCore.rgb, band(heat, 0.8) * (1.0 - band(own, ink + 1.8 * heat)));
                half_.rgb = mix(half_.rgb, hot * half_.a, cover(hw - own) * step(0.02, heat));
                half_.rgb = mix(half_.rgb, u.cRubber.rgb * half_.a, cover(ink - own));
            }
            col = half_ + col * (1.0 - half_.a);
        }
        // Speed lines streaming off the edge into the gap as it is flung, back the way
        // it came, each tapering from its head at the edge to a point, gone within
        // about a fifth of a second so the new wallpaper is left clean.
        float burst = 1.0 - smoothstep(0.08, 0.2, s);
        if (own < 0.0 && s > 0.0 && burst > 0.0) {
            float rowH = 30.0;
            float row = floor(src.y / rowH);
            vec3 h = vec3(hash(vec2(row, 7.0 + float(side))), hash(vec2(row, 9.0 + float(side))),
                          hash(vec2(row, 11.0 + float(side))));
            if (h.x < 0.32) {
                // Hugging the edge, and longer the faster it goes.
                float back = -own - 2.0;
                float len = (30.0 + 260.0 * s) * mix(0.4, 1.0, h.y) * burst;
                float w = mix(1.6, 3.2, h.z) * burst;
                float cy = (row + 0.5 + 0.4 * (h.y - 0.5)) * rowH;
                float taper = mix(1.0, 0.12, clamp(back / max(len, 1.0), 0.0, 1.0));
                float d = length(vec2(back - clamp(back, 0.0, len), src.y - cy)) - w * taper;
                vec3 dc = h.z < 0.55 ? u.cGlow.rgb : u.cEdge.rgb;
                vec4 dsh = over(vec4(0.0), u.cRubber.rgb, cover(1.5 - d));
                dsh = over(dsh, dc, cover(-d));
                col = dsh * (1.0 - col.a) + col;
            }
        }
    }

    // ── Sparks spilling into the gap, carried apart and falling, each a fat
    //    teardrop along its flight. They stay within the gap's reach of the tear,
    //    so most pixels skip them ──
    if (s > 0.0 && s < 0.32 && abs(p.x - tx) < gap + 0.3 * W) {
        float bx = (floor(p.y / BAND) + 0.5) / u.bands;
        for (int i = 0; i < SLOTS; i++) {
            vec4 e = texture(embers, vec2(bx, (float(2 * i) + 0.5) / float(2 * SLOTS)));
            if (e.z < 0.0)
                break;
            if (abs(p.y - e.y) > REACH)
                continue;
            vec4 lt = texture(embers, vec2(bx, (float(2 * i) + 1.5) / float(2 * SLOTS)));
            float r = e.z;
            vec2 tail = e.xy - lt.zw * r * 3.6;
            vec2 pa = p - tail, ba = e.xy - tail;
            float k = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
            float d = length(pa - ba * k) - r * mix(0.15, 0.75, k * k);
            vec3 ec = mix(u.cEdge.rgb, u.cGlow.rgb, lt.y);
            ec = mix(ec, u.cCore.rgb, step(0.8, k));
            col = mix(col, vec4(u.cRubber.rgb, 1.0), cover(1.2 - d) * lt.x);
            col = mix(col, vec4(ec, 1.0), cover(-d) * lt.x);
        }
    }

    // ── The impact frame: for an instant as it lands, the picture printed in comic
    //    halftone, ink dots as big as it is dark on paper lit by the bolt; then a
    //    flash that dies ──
    if (t > STRIKE && t < STRIKE + IMPACT) {
        float lum = dot(col.rgb, vec3(0.3, 0.55, 0.15)) / max(col.a, 1e-3);
        vec2 q = rot(p, 0.785) / 9.0;
        float r = 0.66 * sqrt(clamp(1.08 - lum * 1.25, 0.0, 1.0));
        float dot_ = cover((r - length(fract(q) - 0.5)) * 9.0);
        col.rgb = mix(mix(u.cGlow.rgb, u.cCore.rgb, 0.55), u.cRubber.rgb, dot_) * col.a;
    }
    float flash = step(STRIKE + IMPACT, t) * (1.0 - smoothstep(STRIKE + IMPACT, 0.22, t));
    col.rgb = mix(col.rgb, u.cCore.rgb * col.a, 0.22 * flash);

    // ── A comic starburst where it lands, popping out and shrinking away ──
    float kb = span(t, STRIKE * 0.9, 0.5);
    if (kb > 0.0 && kb < 1.0) {
        float sc = backOut(kb / 0.25) * (1.0 - smoothstep(0.5, 1.0, kb));
        float R = H * 0.3 * max(sc, 0.01);
        vec2 q = rot(p - vec2(tearX(H), H), 0.4 * kb);
        if (length(q) < R * 1.05) {
            float d0 = starDist(q, 12.0, R * 0.5, R, 1.0);
            float d1 = starDist(rot(q, 0.5 * TAU / 12.0), 12.0, R * 0.34, R * 0.7, 2.0);
            float d2 = starDist(q, 12.0, R * 0.18, R * 0.38, 3.0);
            vec4 b = over(vec4(0.0), u.cRubber.rgb, cover(3.0 - d0));
            b = over(b, u.cPaint.rgb, cover(-d0));
            b = over(b, u.cGlow.rgb, cover(-d1));
            b = over(b, u.cCore.rgb, cover(-d2));
            col = b + col * (1.0 - b.a);
        }
    }

    // ── The bolt, striking down, holding, and blinking out: fat and tapering,
    //    banded from a white-hot core through yellow to an orange edge inside its
    //    ink, in a glow of two flat rings; jagged forks splay off it ──
    float on = (1.0 - step(0.45, t)) * max(step(t, 0.3), step(0.5, fract((t - 0.3) / 0.15 * 2.0 + 0.25)));
    float tip = H * min(1.0, t / STRIKE);
    if (on > 0.0 && p.y < tip + 30.0 && abs(p.x - tx) < 320.0) {
        // The path as straight runs between rows 24 px apart, near enough to it under
        // the stroke, and exact round its corners, where a row's slope is not.
        float y0 = floor(p.y / 24.0) * 24.0 - 72.0;
        vec2 prev = vec2(texture(tear, vec2((max(y0, 0.0) + 0.5) / u.columns, 0.25)).x, y0);
        float dm = 1e5;
        for (int k = 1; k <= 7; k++) {
            float yk = y0 + float(k) * 24.0;
            vec2 cur = vec2(texture(tear, vec2((clamp(yk, 0.0, H) + 0.5) / u.columns, 0.25)).x, yk);
            dm = min(dm, sdSeg(p, prev, cur));
            prev = cur;
        }
        float w = mix(22.0, 9.0, p.y / H) * (1.0 - 0.55 * s);
        float d = dm - w;
        float wb = w;
        // Forks, read from the table, near where they could be.
        {
            for (int i = 0; i < FORKS; i++) {
                vec4 f0 = traits(float(2 * i));
                if (p.y < f0.y - 30.0)
                    continue;
                vec4 f1 = traits(float(2 * i + 1));
                float len = f1.w - f0.y;
                float fw = 8.0 * (1.0 - 0.55 * s);
                float df = min(min(sdSeg(p, f0.xy, f0.zw), sdSeg(p, f0.zw, f1.xy)), sdSeg(p, f1.xy, f1.zw));
                float fd = df - fw * mix(1.0, 0.1, clamp((p.y - f0.y) / max(len, 1.0), 0.0, 1.0));
                if (fd < d) {
                    d = fd;
                    wb = fw;
                }
            }
        }
        d = max(d, p.y - tip);
        float inner = -d / wb;          // 0 at its edge .. 1 along its middle
        // Its light on what lies round it, in two rings.
        float ring = cover(34.0 - d) * 0.35 + cover(15.0 - d) * 0.4;
        col.rgb += (col.rgb * 0.8 + u.cGlow.rgb * 0.1 * col.a) * ring * on;
        col.rgb = min(col.rgb, vec3(col.a));
        vec4 b = over(vec4(0.0), u.cRubber.rgb, cover(3.5 - d));
        b = over(b, u.cEdge.rgb, cover(-d));
        b = over(b, u.cGlow.rgb, cover(inner - 0.28) * cover(-d));
        b = over(b, u.cCore.rgb, cover(inner - 0.62) * cover(-d));
        col = b * on + col * (1.0 - b.a * on);
    }

    fragColor = col * u.qt_Opacity;
}
